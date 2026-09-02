import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/currency.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../group_gift/data/group_gift_repository.dart';
import '../../group_gift/domain/group_gift.dart';
import '../../wishlist/presentation/occasion_labels_provider.dart';
import '../../wishlist/presentation/widgets/product_detail_body.dart';
import '../domain/gift.dart';
import '../domain/gift_list_item.dart';
import 'gift_item_controller.dart';
import 'widgets/reserve_gift_sheet.dart';

/// Figma `291:1170` — an item on someone else's wishlist.
///
/// The same page as the owner's own Product Details (`280:300`); only the
/// actions differ, which is why the body above them is shared code.
class GiftItemScreen extends ConsumerStatefulWidget {
  const GiftItemScreen({
    required this.wishlistId,
    required this.itemId,
    super.key,
  });

  final String wishlistId;
  final String itemId;

  @override
  ConsumerState<GiftItemScreen> createState() => _GiftItemScreenState();
}

class _GiftItemScreenState extends ConsumerState<GiftItemScreen> {
  (String, String) get _arg => (widget.wishlistId, widget.itemId);

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(giftItemProvider(_arg).notifier).ensureLoaded(),
    );
  }

  void _report() {
    final error = ref.read(giftItemProvider(_arg)).error;
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _reserve() async {
    final confirmed = await ReserveGiftSheet.show(
      context,
      holdDuration: kReservationHold,
    );
    if (!confirmed || !mounted) return;

    final gift = await ref.read(giftItemProvider(_arg).notifier).reserve();
    if (!mounted) return;
    if (gift == null) {
      _report();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reserved. It is yours to buy.')),
    );
  }

  Future<void> _release() async {
    final ok = await ref.read(giftItemProvider(_arg).notifier).release();
    if (!mounted) return;
    if (!ok) _report();
  }

  /// "Gift Now" goes to the delivery/message step, which is where the merchant
  /// hand-off happens. Reserving first is deliberate: without a hold, someone
  /// else can claim the item while you are still at the merchant's checkout.
  Future<void> _giftNow() async {
    final notifier = ref.read(giftItemProvider(_arg).notifier);
    if (ref.read(giftItemProvider(_arg)).myGift == null) {
      final gift = await notifier.reserve();
      if (!mounted) return;
      if (gift == null) {
        _report();
        return;
      }
    }
    if (!mounted) return;
    await context.push<void>(
      AppRoutes.giftDetails(widget.wishlistId, widget.itemId),
    );
  }

  void _startGroupGift() {
    context.push<void>(
      AppRoutes.createGroupGift(widget.wishlistId, widget.itemId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(giftItemProvider(_arg));
    final occasionLabels = ref.watch(occasionLabelsProvider).value;
    final colors = context.colors;
    final item = state.item;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      body: SafeArea(
        child: item == null
            ? state.error == null
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          WishtickErrorText(state.error!),
                          const SizedBox(height: AppSpacing.md),
                          TextButton(
                            onPressed: () => unawaited(
                              ref
                                  .read(giftItemProvider(_arg).notifier)
                                  .refresh(),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      children: [
                        ProductDetailHeader(
                          title: item.title,
                          subtitle: item.category,
                          imageUrl: item.coverImageUrl,
                          amountMinor: item.price.amountMinor,
                          notes: item.notes,
                        ),
                        if (state.myGift != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _MyGiftBanner(gift: state.myGift!),
                        ] else if (state.claimedByOther) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const _ClaimedBanner(),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        GiftSummaryCard(
                          recipientName: item.recipientName,
                          occasionLabel: item.occasionKey == null
                              ? null
                              : occasionLabels?[item.occasionKey] ??
                                    item.occasionKey,
                          wishlistTitle: state.wishlist?.title,
                          importance: item.importance,
                          createdAt: item.createdAt,
                          // A friend's list: the item view carries no author,
                          // so the date stands alone rather than naming
                          // someone we have not been told about.
                        ),
                      ],
                    ),
                  ),
                  _Actions(
                    state: state,
                    // Null while it loads, which is the same as "none" here:
                    // the buttons it replaces are refused by the server
                    // anyway, so a moment of the old ones is no worse than a
                    // spinner over the whole bar.
                    groupGift: ref
                        .watch(itemGroupGiftProvider(widget.itemId))
                        .value,
                    onReserve: () => unawaited(_reserve()),
                    onRelease: () => unawaited(_release()),
                    onGiftNow: () => unawaited(_giftNow()),
                    onGroupGift: _startGroupGift,
                    onTrack: () => unawaited(
                      context.push<void>(AppRoutes.giftOrder(state.myGift!.id)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The group gift already collecting for this item, if any.
///
/// Its own call rather than a field on the item: the item view is shared with
/// the owner and with link holders, and whether a group is collecting is
/// exactly the thing the recipient must not be told.
final itemGroupGiftProvider = FutureProvider.family<ItemGroupGift?, String>((
  ref,
  itemId,
) {
  return ref.watch(groupGiftRepositoryProvider).groupGiftForItem(itemId);
});

/// The three CTAs from the mock, in its order: Reserve / Gift Now on one row,
/// Start a Group Gift beneath.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.state,
    required this.groupGift,
    required this.onReserve,
    required this.onRelease,
    required this.onGiftNow,
    required this.onGroupGift,
    required this.onTrack,
  });

  final GiftItemState state;

  /// The group already collecting for this item. When there is one, every CTA
  /// here is refused by the server, so the only honest offer is a way in.
  final ItemGroupGift? groupGift;
  final VoidCallback onReserve;
  final VoidCallback onRelease;
  final VoidCallback onGiftNow;
  final VoidCallback onGroupGift;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final busy = state.busy;

    // Nothing to offer: you own the list, or you are holding a link without
    // being signed in. Either way the server would refuse a reservation, so
    // showing the buttons would only produce a 403 on tap.
    if (!state.canGift && state.myGift == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Sign in as a friend of this wishlist to gift from it.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(color: colors.textMuted),
        ),
      );
    }

    if (state.isPurchasedByMe) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state.myGift?.mode == GiftMode.online ? onTrack : null,
            child: Text(
              state.myGift?.mode == GiftMode.online
                  ? 'Track Order'
                  : 'Bought elsewhere — nothing to track',
            ),
          ),
        ),
      );
    }

    final group = groupGift;
    if (group != null) {
      return _GroupGiftRunning(group: group);
    }

    if (state.claimedByOther) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Someone has already claimed this gift.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
      );
    }

    final reserved = state.isReservedByMe;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : (reserved ? onRelease : onReserve),
                  child: Text(
                    reserved ? 'Release' : 'Reserve Gift',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onGiftNow,
                  child: const Text(
                    'Gift Now',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: busy ? null : onGroupGift,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.celebration),
                foregroundColor: colors.celebration,
              ),
              child: const Text('Start a Group Gift'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Your own hold, counting down from the server's `expiresAt` — the real
/// deadline, not the estimate the reserve sheet showed.
class _MyGiftBanner extends StatefulWidget {
  const _MyGiftBanner({required this.gift});

  final GiftListItem gift;

  @override
  State<_MyGiftBanner> createState() => _MyGiftBannerState();
}

class _MyGiftBannerState extends State<_MyGiftBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.gift.expiresAt != null) {
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Only a live hold has a clock; every later state is a settled fact.
  String _label() {
    final gift = widget.gift;
    if (gift.status != GiftStatus.reserved) {
      return switch (gift.status) {
        GiftStatus.purchased => 'You have bought this.',
        GiftStatus.fulfilled => 'Delivered.',
        GiftStatus.completed => 'Received.',
        _ => 'Cancelled.',
      };
    }

    final left = gift.timeLeft();
    if (left == null) return 'Reserved by you.';
    if (left == Duration.zero) return 'Your reservation has expired.';
    return 'Reserved by you — expires in ${formatHoldCountdown(left)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.primarySubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            widget.gift.status == GiftStatus.reserved
                ? Icons.lock_clock
                : Icons.check_circle_outline,
            color: colors.primary,
            size: AppSizes.iconMd,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              _label(),
              style: context.text.bodySmall?.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimedBanner extends StatelessWidget {
  const _ClaimedBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            Icons.card_giftcard,
            color: colors.textSecondary,
            size: AppSizes.iconMd,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              // Who claimed it is withheld by the server, on purpose — naming
              // them would spoil a surprise for everyone reading the list.
              'Already claimed by another gifter.',
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

/// "A group gift is already running for this" — the item screen's only offer
/// once an item is claimed by a group.
///
/// Replaces Reserve / Gift Now / Start a Group Gift outright rather than
/// disabling them: all three are refused with a 409, and a row of dead buttons
/// tells the reader nothing about the thing they could actually do.
class _GroupGiftRunning extends StatelessWidget {
  const _GroupGiftRunning({required this.group});

  final ItemGroupGift group;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final contributors = group.contributorLine;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A group gift is already running',
                  style: context.text.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${formatInrMinor(group.collectedAmountMinor)} of '
                  '${formatInrMinor(group.targetAmountMinor)} collected'
                  '${contributors == null ? '' : ' · $contributors'}',
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: group.percentFunded / 100,
                    minHeight: 6,
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () =>
                unawaited(context.push<void>(AppRoutes.groupGift(group.id))),
            child: const Text('View group gift'),
          ),
        ],
      ),
    );
  }
}
