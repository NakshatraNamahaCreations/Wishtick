import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/currency.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../domain/group_gift.dart';
import 'group_gift_controller.dart';
import 'widgets/contribute_sheet.dart';
import 'widgets/group_gift_widgets.dart';

/// "Group Gift Details" (`316:166`) — the live group, as everyone but the host
/// mid-creation sees it.
class GroupGiftDetailsScreen extends ConsumerStatefulWidget {
  const GroupGiftDetailsScreen({required this.groupGiftId, super.key});

  final String groupGiftId;

  @override
  ConsumerState<GroupGiftDetailsScreen> createState() =>
      _GroupGiftDetailsScreenState();
}

class _GroupGiftDetailsScreenState
    extends ConsumerState<GroupGiftDetailsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(groupGiftProvider(widget.groupGiftId).notifier).ensureLoaded();
    });
  }

  Future<void> _contribute(GroupGift gift) async {
    final draft = await showContributeSheet(context, gift: gift);
    if (draft == null || !mounted) return;
    final ok = await ref
        .read(groupGiftProvider(widget.groupGiftId).notifier)
        .contribute(
          amountMinor: draft.amountMinor,
          message: draft.message,
          // Minted per confirmed intent: a retry of *this* pledge must not
          // become a second one.
          idempotencyKey: newIdempotencyKey(),
        );
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          gift.hostUpiId == null
              ? 'Pledged. The host will share where to send it.'
              : 'Pledged — now send ${formatInrMinor(draft.amountMinor)} '
                    'to ${gift.hostUpiId}.',
        ),
      ),
    );
  }

  /// Bought, so a thank-you is possible.
  bool _thankable(GroupGift gift) => const {
    GroupGiftStatus.purchased,
    GroupGiftStatus.fulfilled,
  }.contains(gift.status);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupGiftProvider(widget.groupGiftId));
    final gift = state.gift;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Gift Details'),
        actions: [
          if (gift != null) ...[
            IconButton(
              onPressed: () => context.push<void>(
                AppRoutes.groupGiftParticipants(gift.id),
              ),
              icon: const Icon(Icons.group_outlined),
              tooltip: 'Participants',
            ),
            // The chat is provisioned with the group gift, so a null chatId
            // means this caller cannot see it rather than that none exists.
            if (gift.chatId != null)
              IconButton(
                onPressed: () => context.push<void>(
                  AppRoutes.groupGiftChat(gift.id),
                  extra: gift.chatId,
                ),
                icon: const Icon(Icons.forum_outlined),
                tooltip: 'Group chat',
              ),
          ],
        ],
      ),
      body: gift == null
          ? Center(
              child: state.error != null
                  ? WishtickErrorText(state.error!)
                  : const CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: () => ref
                  .read(groupGiftProvider(widget.groupGiftId).notifier)
                  .refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  if (gift.items.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: AspectRatio(
                        aspectRatio: 1.16,
                        child: WishtickImage(url: gift.items.first.imageUrl),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    gift.title,
                    style: context.text.titleLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  _Progress(gift: gift),

                  if (gift.message != null && gift.message!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _WhyCard(message: gift.message!),
                  ],

                  const SizedBox(height: AppSpacing.xxl),
                  const GroupGiftSectionLabel('Gift summary'),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Column(
                      children: [
                        for (final item in gift.items)
                          CostRow(
                            label: item.title,
                            amountMinor: item.amountMinor ?? 0,
                          ),
                        for (final charge in gift.charges)
                          CostRow(
                            label: charge.label,
                            amountMinor: charge.amountMinor,
                          ),
                        CostRow(
                          label: 'Grand Total',
                          amountMinor: gift.targetAmountMinor,
                          emphasised: true,
                        ),
                      ],
                    ),
                  ),

                  // Without this the summary, picker and charges screens are
                  // unreachable once creation is done — a host who backed out
                  // mid-flow had no way back to the bill they were building.
                  if (gift.canManage && gift.billEditable) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    OutlinedButton(
                      onPressed: () => context.push<void>(
                        AppRoutes.groupGiftSummary(gift.id),
                      ),
                      child: const Text('Edit gifts & charges'),
                    ),
                  ],

                  if (gift.canManage) ...[
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: () => context.push<void>(
                        AppRoutes.groupGiftSettle(gift.id),
                      ),
                      child: const Text('Settle up'),
                    ),
                  ],

                  // Shown once there is a note, or once the gift has been
                  // bought and the recipient could write one.
                  if (gift.hasThankYou || _thankable(gift)) ...[
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: () => context.push<void>(
                        AppRoutes.groupGiftThankYou(gift.id),
                      ),
                      child: Text(
                        gift.hasThankYou
                            ? 'Read the thank-you note'
                            : 'Thank-you note',
                      ),
                    ),
                  ],

                  if (state.error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    WishtickErrorText(state.error!),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: gift == null
          ? null
          : Container(
              color: colors.background,
              child: GroupGiftFooter(
                label: gift.hasContributed ? 'Contribute again' : 'Chip In',
                busy: state.busy,
                // A closed group takes no more money; the button says so
                // rather than failing on tap.
                onPressed: gift.status.acceptsContributions
                    ? () => _contribute(gift)
                    : null,
              ),
            ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.gift});

  final GroupGift gift;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final left = gift.targetAmountMinor - gift.collectedAmountMinor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${formatInrMinor(gift.collectedAmountMinor)} of '
                '${formatInrMinor(gift.targetAmountMinor)} collected',
                style: context.text.bodyLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${gift.percentFunded}%',
              style: context.text.bodyLarge?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            // The server clamps this to 0..100, so the bar and the label can
            // never disagree.
            value: gift.percentFunded / 100,
            minHeight: AppSpacing.sm,
            backgroundColor: colors.border,
            color: colors.accent,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          left > 0
              ? '${formatInrMinor(left)} to go · '
                    '${gift.contributorCount} contributing'
              : 'Fully funded · ${gift.contributorCount} contributing',
          style: context.text.bodySmall?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.accentSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.card_giftcard,
              size: AppSizes.iconMd,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why I picked this gift',
                  style: context.text.titleSmall?.copyWith(
                    color: context.headlineBrandColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
