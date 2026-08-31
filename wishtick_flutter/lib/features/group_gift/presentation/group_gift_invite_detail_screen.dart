import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/currency.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../data/group_gift_repository.dart';
import '../domain/group_gift.dart';
import 'group_gift_invites_screen.dart';

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

  Future<void> _respond(
    GroupGiftInviteDetail detail, {
    required bool accept,
  }) async {
    if (_busy) return;
    // Declining is the one that cannot be taken back — the invitation is gone
    // and only the host can send another — so it asks first. Accepting is
    // recoverable by leaving the group, and a confirm on both would train
    // people to tap through the one that matters.
    if (!accept && !await _confirmDecline(detail)) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(groupGiftRepositoryProvider)
          .respondToInvite(widget.inviteId, accept: accept);
      if (!mounted) return;
      ref.invalidate(groupGiftInvitesProvider);
      if (accept) {
        // Into the group they just joined: the answer to yes is the page where
        // they can put money in.
        context.pushReplacement(AppRoutes.groupGift(detail.invite.groupGiftId));
      } else {
        // Back to the list — or *to* it, when this screen is the whole stack.
        // A notification or a cold link can land here directly, and popping
        // the only route throws "There is nothing to pop".
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.groupGiftInvites);
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitation declined')));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // The group can close, or the invitation be answered on another device,
      // between the screen being drawn and the button being pressed.
      ref.invalidate(groupGiftInviteDetailProvider(widget.inviteId));
      ref.invalidate(groupGiftInvitesProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _respond(value, accept: false),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _respond(value, accept: true),
                    child: const Text('Accept'),
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
