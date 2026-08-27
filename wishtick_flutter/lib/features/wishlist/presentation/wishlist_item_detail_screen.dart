import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../gifting/data/gifting_repository.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import 'item_detail_controller.dart';
import 'occasion_labels_provider.dart';
import 'widgets/catalogue_detail_sections.dart';
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

  /// The catalogue row behind this item, once fetched. Null until then, and
  /// for good on an item added by hand — which has no catalogue row.
  NormalizedProduct? _catalogue;
  bool _loadingCatalogue = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(itemDetailProvider(_arg).notifier).ensureLoaded();
      unawaited(
        ref
            .read(wishlistDetailProvider(widget.wishlistId).notifier)
            .ensureLoaded(),
      );
      unawaited(_loadCatalogue());
    });
  }

  /// Fetches what the item's snapshot could not carry: the seller, the rating,
  /// the other sellers, the specification table.
  ///
  /// Deliberately not awaited before first paint — it is a second upstream
  /// call and takes seconds, while the item itself is already on screen. A
  /// failure is silent for the same reason: the page was never incomplete,
  /// only less detailed.
  Future<void> _loadCatalogue() async {
    if (!mounted) return;
    final productId = ref.read(itemDetailProvider(_arg)).item?.sourceProductId;
    if (productId == null) return;

    setState(() => _loadingCatalogue = true);
    try {
      final product = await ref
          .read(productRepositoryProvider)
          .detailsById(productId);
      if (!mounted) return;
      setState(() {
        _catalogue = product;
        _loadingCatalogue = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _loadingCatalogue = false);
    }
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

  /// Opens one seller through our affiliate redirect.
  ///
  /// Via `/r/p/...` rather than the offer's own URL: the redirect converts the
  /// link, records the click and attaches the tracking id. Going straight to
  /// `offer.url` would work and earn nothing.
  Future<void> _openSeller(int index) async {
    final product = _catalogue;
    if (product == null) return;

    await _open(
      ref
          .read(giftingRepositoryProvider)
          .productRedirectUri(
            product.provider,
            product.externalId,
            offerIndex: index,
          ),
    );
  }

  /// "Gift Now" — straight out to the merchant.
  ///
  /// No recipient step, unlike the search page's version: this item is already
  /// on a list and already tagged with who it is for, so the only question left
  /// is where to buy it. Nor is a `Gift` record created — Wishtick takes no
  /// payment, and the purchase happens at the merchant.
  ///
  /// Through `/r/:itemId` rather than the catalogue redirect the seller rows
  /// use: this one carries the item and its wishlist, so the click is
  /// attributable to the list it was saved on.
  Future<void> _giftNow() => _open(
    ref.read(giftingRepositoryProvider).affiliateRedirectUri(widget.itemId),
  );

  Future<void> _open(Uri uri) async {
    // externalApplication, not the in-app view: the affiliate cookie has to
    // land in the browser the purchase will actually happen in.
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Couldn't open the store.")));
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

    final offers = _catalogue?.offers ?? const <ProductOffer>[];
    final features = _catalogue?.features ?? const <ProductFeature>[];
    final sellerLine = SellerRatingLine(
      // The catalogue's merchant, not the item's: the item never stored one.
      merchant: _catalogue?.merchant,
      rating: _catalogue?.rating,
      reviewCount: _catalogue?.reviewCount,
    );

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
                        // The gallery, seller line and price are drawn here
                        // rather than through ProductDetailHeader: that widget
                        // shows a single image and no seller, and it is shared
                        // with the gifting screens, which are not mine to
                        // change.
                        CatalogueGallery(
                          imageUrls: _catalogue?.imageUrls.isNotEmpty ?? false
                              ? _catalogue!.imageUrls
                              // The item's own snapshot until the catalogue
                              // lands, so the page is never imageless.
                              : item.imageUrls,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          item.title,
                          style: context.text.headlineSmall?.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        if (sellerLine.hasAnything) ...[
                          const SizedBox(height: AppSpacing.sm),
                          sellerLine,
                        ],
                        const SizedBox(height: AppSpacing.md),
                        CataloguePrice(
                          // The item's price, not the catalogue's: the
                          // snapshot is what the owner saved, and quietly
                          // replacing it with today's figure would rewrite
                          // what they chose.
                          amountMinor: item.price.amountMinor,
                          listPriceMinor: _catalogue?.listPriceMinor,
                        ),
                        if (_catalogue?.deliveryNote != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          DeliveryNote(note: _catalogue!.deliveryNote!),
                        ],
                        if (item.notes != null && item.notes!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          WhyThisGiftCard(notes: item.notes!),
                        ],
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

                        // Everything below arrives from the catalogue lookup,
                        // so it appears a beat after the page does. A slim
                        // progress line says more is coming without implying
                        // the page is broken.
                        if (_loadingCatalogue && _catalogue == null) ...[
                          const SizedBox(height: AppSpacing.xl),
                          LinearProgressIndicator(
                            minHeight: 2,
                            backgroundColor: colors.surfaceAlt,
                          ),
                        ],

                        if (offers.length > 1) ...[
                          const SizedBox(height: AppSpacing.xl),
                          CatalogueSectionTitle(
                            'Available at ${offers.length} sellers',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final (index, offer) in offers.indexed)
                            CatalogueOfferRow(
                              offer: offer,
                              // The first is the cheapest total.
                              best: index == 0,
                              onTap: () => _openSeller(index),
                            ),
                        ],

                        if (features.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xl),
                          CatalogueSectionTitle(
                            _catalogue?.brand == null
                                ? 'Details'
                                : 'About this ${_catalogue!.brand!}',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          CatalogueFeatureTable(features: features),
                        ],
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
