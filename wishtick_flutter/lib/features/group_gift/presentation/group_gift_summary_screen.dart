import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/currency.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../domain/group_gift.dart';
import 'group_gift_controller.dart';
import 'widgets/group_gift_widgets.dart';

/// "Group Gift Summary" (`4007:801` empty of charges, `4006:463` with them).
///
/// Step 2 of creation: what the group is buying, before the bill is closed.
/// The two frames are one screen — the charge section simply appears once
/// there is a charge to show.
class GroupGiftSummaryScreen extends ConsumerStatefulWidget {
  const GroupGiftSummaryScreen({
    required this.groupGiftId,
    this.initial,
    super.key,
  });

  final String groupGiftId;

  /// Handed straight over by the create screen, so the summary paints with
  /// real numbers instead of a spinner it does not need.
  final GroupGift? initial;

  @override
  ConsumerState<GroupGiftSummaryScreen> createState() =>
      _GroupGiftSummaryScreenState();
}

class _GroupGiftSummaryScreenState
    extends ConsumerState<GroupGiftSummaryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final controller = ref.read(
        groupGiftProvider(widget.groupGiftId).notifier,
      );
      final initial = widget.initial;
      if (initial != null) {
        controller.seed(initial);
      } else {
        controller.ensureLoaded();
      }
    });
  }

  Future<void> _remove(GroupGiftItem item) async {
    final lineId = item.lineId;
    if (lineId == null) return;
    await ref
        .read(groupGiftProvider(widget.groupGiftId).notifier)
        .removeGiftLine(lineId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupGiftProvider(widget.groupGiftId));
    final gift = state.gift ?? widget.initial;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Group Gift Summary')),
      body: gift == null
          ? Center(
              child: state.error != null
                  ? WishtickErrorText(state.error!)
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                GroupGiftSectionLabel('Selected Gifts (${gift.items.length})'),
                const SizedBox(height: AppSpacing.md),
                for (final item in gift.items) ...[
                  _GiftRow(
                    item: item,
                    onRemove: state.busy ? null : () => _remove(item),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: state.busy
                      ? null
                      : () => context.push<void>(
                          AppRoutes.groupGiftAddItem(gift.id),
                        ),
                  child: const Text('+  Add Another Gift'),
                ),
                if (gift.charges.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  const GroupGiftSectionLabel('Added charges'),
                  const SizedBox(height: AppSpacing.md),
                  for (final charge in gift.charges) ...[
                    ChargeRow(charge: charge),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
                if (state.error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  WishtickErrorText(state.error!),
                ],
              ],
            ),
      bottomNavigationBar: gift == null
          ? null
          : Container(
              color: colors.background,
              // Not in the frames: neither summary export carries a CTA, but
              // the flow has to reach "Miscellaneous Charges" somehow, and
              // "+ Add Another Gift" is the only other control on the screen.
              child: GroupGiftFooter(
                label: 'Continue',
                busy: state.busy,
                onPressed: () =>
                    context.push<void>(AppRoutes.groupGiftCharges(gift.id)),
                child: gift.charges.isEmpty
                    ? null
                    : CostSummaryCard(
                        giftsTotalMinor: gift.giftsTotalMinor,
                        chargesTotalMinor: gift.chargesTotalMinor,
                        grandTotalMinor: gift.targetAmountMinor,
                      ),
              ),
            ),
    );
  }
}

/// One "Selected Gifts" row: thumbnail, title, price, and — on an extra gift
/// only — the × that drops it back out of the group.
class _GiftRow extends StatelessWidget {
  const _GiftRow({required this.item, this.onRemove});

  final GroupGiftItem item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 72,
              height: 72,
              child: WishtickImage(url: item.imageUrl),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatInrMinor(item.amountMinor),
            style: context.text.bodyLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (item.removable)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close),
              iconSize: AppSizes.iconMd,
              color: colors.textSecondary,
              tooltip: 'Remove ${item.title}',
            )
          else
            // Keeps the primary row's price column aligned with the extras'
            // rather than letting it run to the card edge.
            const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}
