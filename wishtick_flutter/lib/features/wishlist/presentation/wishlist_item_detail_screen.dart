import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import 'item_detail_controller.dart';
import 'occasion_labels_provider.dart';
import 'widgets/choose_wishlist_sheet.dart';
import 'widgets/product_detail_body.dart';
import 'wishlist_detail_controller.dart';
import 'wishlists_controller.dart';

/// Figma `280:300` ("Product Details") â€” one item's full detail, reached
/// from a wishlist's item grid.
class WishlistItemDetailScreen extends ConsumerStatefulWidget {
  const WishlistItemDetailScreen({
    required this.wishlistId,
    required this.itemId,
    super.key,
  });

  final String wishlistId;
  final String itemId;

  @override
  ConsumerState<WishlistItemDetailScreen> createState() =>
      _WishlistItemDetailScreenState();
}

class _WishlistItemDetailScreenState
    extends ConsumerState<WishlistItemDetailScreen> {
  (String, String) get _arg => (widget.wishlistId, widget.itemId);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(itemDetailProvider(_arg).notifier).ensureLoaded();
      ref
          .read(wishlistDetailProvider(widget.wishlistId).notifier)
          .ensureLoaded();
    });
  }

  Future<void> _remove() async {
    final ok = await ref.read(itemDetailProvider(_arg).notifier).remove();
    if (!mounted) return;
    if (ok) {
      unawaited(
        ref.read(wishlistDetailProvider(widget.wishlistId).notifier).refresh(),
      );
      Navigator.of(context).pop();
    } else {
      final error = ref.read(itemDetailProvider(_arg)).error;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  Future<void> _moveToAnother() async {
    await ref.read(wishlistsProvider.notifier).ensureLoaded();
    if (!mounted) return;
    final all = ref.read(wishlistsProvider).wishlists ?? const [];
    final options = all.where((w) => w.id != widget.wishlistId).toList();

    final chosen = await ChooseWishlistSheet.show(context, options: options);
    if (chosen == null || !mounted) return;

    final ok = await ref
        .read(itemDetailProvider(_arg).notifier)
        .moveTo(chosen.id);
    if (!mounted) return;
    if (ok) {
      unawaited(
        ref.read(wishlistDetailProvider(widget.wishlistId).notifier).refresh(),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Moved to ${chosen.title}')));
      Navigator.of(context).pop();
    } else {
      final error = ref.read(itemDetailProvider(_arg)).error;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  void _giftNow() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gifting is coming in a later sprint.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemDetailProvider(_arg));
    final wishlistTitle = ref.watch(
      wishlistDetailProvider(
        widget.wishlistId,
      ).select((s) => s.wishlist?.title),
    );
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
                            onPressed: () => ref
                                .read(itemDetailProvider(_arg).notifier)
                                .refresh(),
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
                          subtitle: null,
                          imageUrl: item.coverImageUrl,
                          amountMinor: item.price.amountMinor,
                          notes: item.notes,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        GiftSummaryCard(
                          recipientName: item.recipientName,
                          occasionLabel: item.occasionKey == null
                              ? null
                              : occasionLabels?[item.occasionKey] ??
                                    item.occasionKey,
                          wishlistTitle: wishlistTitle,
                          importance: item.importance,
                          createdAt: item.createdAt,
                          // Your own list, so the author is not in question.
                          addedBy: 'You',
                        ),
                      ],
                    ),
                  ),
                  Padding(
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
                                onPressed: _remove,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: colors.danger),
                                  foregroundColor: colors.danger,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                  ),
                                ),
                                child: const Text(
                                  'Remove Product',
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _giftNow,
                                child: const Text('Gift Now'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _moveToAnother,
                            child: const Text('Move to Another Wishlist'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
