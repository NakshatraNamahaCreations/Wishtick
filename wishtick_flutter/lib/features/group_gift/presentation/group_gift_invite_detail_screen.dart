import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/currency.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../home/presentation/home_controller.dart';
import '../data/group_gift_repository.dart';
import '../domain/group_gift.dart';
import 'group_gift_invites_screen.dart';
import 'widgets/contribute_sheet.dart';

/// One invitation, with the gift behind it.
final groupGiftInviteDetailProvider =
    FutureProvider.family<GroupGiftInviteDetail, String>((ref, inviteId) {
      return ref.watch(groupGiftRepositoryProvider).inviteDetail(inviteId);
    });

/// What you are being asked to chip in for, and by whom.
///
/// The invitee cannot open the group itself — they are not a participant and
/// the wishlist behind it may be private — so answering used to mean saying yes
/// to a title and nothing else. The invitation is the authority for this much:
/// the item, how far the collection has got, and who is already in.
class GroupGiftInviteDetailScreen extends ConsumerStatefulWidget {
  const GroupGiftInviteDetailScreen({required this.inviteId, super.key});

  final String inviteId;

  @override
  ConsumerState<GroupGiftInviteDetailScreen> createState() =>
      _GroupGiftInviteDetailScreenState();
}

class _GroupGiftInviteDetailScreenState
    extends ConsumerState<GroupGiftInviteDetailScreen> {
  bool _busy = false;

  /// Paying, which is also how the invitation is accepted.
  ///
  /// The sheet opens here rather than on the group's own screen: the invitee
  /// is not a member yet and, on a private list, cannot read the group at all
  /// until they are. The server takes the contribution as the answer.
  Future<void> _contribute(GroupGiftInviteDetail detail) async {
    if (_busy) return;
    final draft = await showContributeSheet(
      context,
      suggestedAmountsMinor: detail.suggestedAmountsMinor,
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(groupGiftRepositoryProvider)
          .contribute(
            detail.invite.groupGiftId,
            amountMinor: draft.amountMinor,
            message: draft.message,
            // Minted per confirmed intent: a retry of *this* pledge must not
            // become a second one.
            idempotencyKey: newIdempotencyKey(),
          );
      if (!mounted) return;
      _refreshWhatThisChanged();
      // The designed confirmation (`316:298`) — where to send the money is the
      // one thing a contributor must not lose.
      await context.push<void>(
        AppRoutes.groupGiftContributed(detail.invite.groupGiftId),
        extra: (
          amountMinor: draft.amountMinor,
          hostName: detail.hostName,
          hostUpiId: detail.hostUpiId,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showFailure(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Not Interested? Decline Invitation".
  ///
  /// The one answer that cannot be taken back — the invitation is gone and
  /// only the host can send another — so it asks first, and it is the only
  /// action here that does.
  Future<void> _decline(GroupGiftInviteDetail detail) async {
    if (_busy || !await _confirmDecline(detail)) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(groupGiftRepositoryProvider)
          .respondToInvite(widget.inviteId, accept: false);
      if (!mounted) return;
      _refreshWhatThisChanged();
      _leave();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation declined')));
    } on ApiException catch (e) {
      if (!mounted) return;
      _showFailure(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Home's chip-in rail carries this gift for as long as the invitation
  /// stands, so both answers change what is on Home — not just this list.
  ///
  /// Home is *refreshed*, not invalidated: its notifier builds an empty state
  /// and fills it from `ensureLoaded` in the screen's `initState`, which does
  /// not run again while the tab stays mounted underneath. Invalidating it
  /// would blank Home until a pull-to-refresh. The invitations list is a
  /// FutureProvider that fetches in its own build, so it is the other way
  /// round there.
  void _refreshWhatThisChanged() {
    ref.invalidate(groupGiftInvitesProvider);
    unawaited(ref.read(homeProvider.notifier).refresh());
  }

  /// Back to the list — or *to* it, when this screen is the whole stack. A
  /// notification or a cold link can land here directly, and popping the only
  /// route throws "There is nothing to pop".
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.groupGiftInvites);
    }
  }

  void _showFailure(ApiException e) {
    // The group can close, or the invitation be answered on another device,
    // between the screen being drawn and the button being pressed.
    ref.invalidate(groupGiftInviteDetailProvider(widget.inviteId));
    ref.invalidate(groupGiftInvitesProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
  }

  Future<bool> _confirmDecline(GroupGiftInviteDetail detail) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline this invitation?'),
        content: Text(
          '${detail.invite.inviterName} asked you to chip in for '
          '${detail.itemTitle}. You will not be able to join again unless '
          'they invite you a second time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Decline',
              style: TextStyle(color: context.colors.danger),
            ),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final detail = ref.watch(groupGiftInviteDetailProvider(widget.inviteId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'Group Gift Invite'),
      // Error before loading: Riverpod retries a failed provider, so one that
      // has failed is also loading — the other order spins forever.
      body: switch (detail) {
        AsyncValue(hasError: true, hasValue: false) => Center(
          child: WishtickErrorText('Could not load this invitation.'),
        ),
        AsyncValue(hasValue: false) => const Center(
          child: CircularProgressIndicator(),
        ),
        AsyncValue(:final value?) => _Body(detail: value),
        _ => const SizedBox.shrink(),
      },
      bottomNavigationBar: switch (detail) {
        AsyncValue(:final value?) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _contribute(value),
                        child: const Text('Contribute to Gift'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        // No answer at all: the invitation stays pending and
                        // the card stays on Home, to be decided later.
                        onPressed: _busy ? null : _leave,
                        child: const Text('Maybe Later'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _decline(value),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.warning,
                      side: BorderSide(color: colors.warning),
                    ),
                    child: const Text('Not Interested? Decline Invitation'),
                  ),
                ),
              ],
            ),
          ),
        ),
        _ => null,
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});

  final GroupGiftInviteDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = detail.imageUrl;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (url != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                // A dead image URL must not take the whole answer with it.
                errorBuilder: (_, _, _) => ColoredBox(
                  color: colors.surface,
                  child: Icon(
                    Icons.card_giftcard_outlined,
                    color: colors.textSecondary,
                    size: AppSizes.avatarLg,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          detail.itemTitle,
          style: context.text.titleLarge?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${detail.invite.inviterName} asked you to chip in',
          style: context.text.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        if (_deadlineLabel(detail) case final label?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: colors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _Progress(detail: detail),
        const SizedBox(height: AppSpacing.xl),
        Text(
          detail.contributors.isEmpty
              ? 'Nobody has chipped in yet'
              : 'Who has chipped in',
          style: context.text.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (detail.contributors.isEmpty)
          Text(
            'You would be the first.',
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          )
        else
          for (final person in detail.contributors)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: AppSizes.avatarSm / 2,
                    backgroundColor: colors.surface,
                    child: Text(
                      person.name.characters.first.toUpperCase(),
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      person.name,
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    formatInrMinor(person.amountMinor),
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.payment,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// How long is left to pay, in the words the design uses (`316:536` shows
/// "2 days left"). Null when the collection has no deadline, and when it has
/// already passed — a negative countdown is worse than none.
String? _deadlineLabel(GroupGiftInviteDetail detail) =>
    switch (detail.daysToDeadline()) {
      null => null,
      < 0 => null,
      0 => 'Last day to chip in',
      1 => '1 day left',
      final days => '$days days left',
    };

/// Total Goal / Collected / Left to go, and the bar.
class _Progress extends StatelessWidget {
  const _Progress({required this.detail});

  final GroupGiftInviteDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatInrMinor(detail.collectedAmountMinor)} of '
                  '${formatInrMinor(detail.targetAmountMinor)} collected',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${detail.percentFunded}%',
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: detail.percentFunded / 100,
              minHeight: 8,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${formatInrMinor(detail.remainingMinor)} to go · '
              '${detail.contributorCount} contributing',
              style: context.text.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
