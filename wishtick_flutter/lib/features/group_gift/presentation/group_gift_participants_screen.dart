import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/currency.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../domain/group_gift.dart';
import 'group_gift_controller.dart';
import 'widgets/group_gift_widgets.dart';
import 'widgets/invite_wishmates_action.dart';

/// "Participants (N)" (`316:536`).
class GroupGiftParticipantsScreen extends ConsumerStatefulWidget {
  const GroupGiftParticipantsScreen({required this.groupGiftId, super.key});

  final String groupGiftId;

  @override
  ConsumerState<GroupGiftParticipantsScreen> createState() =>
      _GroupGiftParticipantsScreenState();
}

class _GroupGiftParticipantsScreenState
    extends ConsumerState<GroupGiftParticipantsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(groupGiftProvider(widget.groupGiftId).notifier).ensureLoaded();
    });
  }

  /// Sums each named member's confirmed contributions.
  ///
  /// Anonymous ones carry no contributor and so land nowhere — deliberately:
  /// the total already counts them, and attributing them here is exactly the
  /// disclosure the contributor opted out of.
  Map<String, int> _paidByUser(GroupGift gift) {
    final totals = <String, int>{};
    for (final c in gift.recentContributions) {
      final id = c.contributor?.userId;
      if (id == null) continue;
      totals[id] = (totals[id] ?? 0) + c.amountMinor;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupGiftProvider(widget.groupGiftId));
    final gift = state.gift;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text('Participants (${gift?.participantCount ?? 0})'),
            Text(
              'Group Members',
              style: context.text.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: gift == null
          ? Center(
              child: state.error != null
                  ? WishtickErrorText(state.error!)
                  : const CircularProgressIndicator(),
            )
          : Builder(
              builder: (context) {
                final paid = _paidByUser(gift);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  children: [
                    _GoalCard(gift: gift),
                    const SizedBox(height: AppSpacing.xl),
                    for (final person in gift.participants)
                      _ParticipantRow(
                        person: person,
                        isHost: person.userId == gift.hostId,
                        paidMinor: paid[person.userId],
                      ),
                  ],
                );
              },
            ),
      bottomNavigationBar: gift == null
          ? null
          : Container(
              color: colors.background,
              child: GroupGiftFooter(
                label: 'Invite Friends & Family',
                // Every member may invite, not only the host: a group gift is
                // a group, and making the one person who started it the only
                // route in is how a collection stalls when they go quiet.
                onPressed: () => unawaited(
                  inviteWishmatesToGroupGift(
                    context,
                    groupGiftId: widget.groupGiftId,
                    title: gift.title,
                    shareUrl: gift.share?.url,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Total Goal / Collected / Left to go (`316:536`).
class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.gift});

  final GroupGift gift;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final left = gift.targetAmountMinor - gift.collectedAmountMinor;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      // Thirds, not three natural widths: the amounts here run to the whole
      // cost of the gift, and ₹17,347 three times over does not fit a 393pt
      // phone. Unconstrained, the third column ran off the right edge.
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'Total Goal',
              value: formatInrMinor(gift.targetAmountMinor),
              color: colors.textPrimary,
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'Collected',
              value: formatInrMinor(gift.collectedAmountMinor),
              color: colors.payment,
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'Left to go',
              value: formatInrMinor(left < 0 ? 0 : left),
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: context.text.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.person,
    required this.isHost,
    this.paidMinor,
  });

  final GroupGiftParticipant person;
  final bool isHost;
  final int? paidMinor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final paid = paidMinor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: AppSizes.avatarSm / 2,
            backgroundColor: colors.optionFill,
            child: Text(
              person.name.characters.first.toUpperCase(),
              style: context.text.bodyMedium?.copyWith(
                color: colors.primaryMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    person.name,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                if (isHost) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      'Host',
                      style: context.text.bodySmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (paid != null && paid > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatInrMinor(paid),
                  style: context.text.bodyLarge?.copyWith(
                    color: colors.payment,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Paid',
                  style: context.text.bodySmall?.copyWith(
                    color: colors.payment,
                  ),
                ),
              ],
            )
          else
            Text(
              'Not yet',
              style: context.text.bodySmall?.copyWith(color: colors.textMuted),
            ),
        ],
      ),
    );
  }
}
