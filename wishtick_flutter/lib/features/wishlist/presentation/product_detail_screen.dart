import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/currency.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import 'save_to_wishlist_screen.dart';
import 'widgets/choose_wishlist_sheet.dart';
import 'wishlists_controller.dart';

/// Figma `280:403` — a searched or resolved product, before it's on any
/// wishlist.
///
/// Shows everything the catalogue actually gives us: seller, price and MRP,
/// the provider's rating and delivery line. All of those are sparse — Google
/// Shopping publishes a rating on a small minority of rows — so each one is
/// hidden when absent rather than drawn empty.
///
/// "Why they'll love it" bullets, "Perfect For", "Recommended Recipients" and
/// "Frequently Gifted Together" still have no backing data (no per-product
/// feature copy, no recommendation engine) and are left out rather than
/// fabricated — gathering who a saved item is for happens for real on
/// [SaveToWishlistScreen], once a wishlist is chosen.
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen._({
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.productUrl,
    required this.amountMinor,
    required this.currency,
    required this.category,
    required this.provider,
    required this.externalId,
    this.merchant,
    this.listPriceMinor,
    this.rating,
    this.reviewCount,
    this.deliveryNote,
    this.brand,
    this.features = const [],
    this.offers = const [],
    super.key,
  });

  factory ProductDetailScreen.fromSearch(
    NormalizedProduct product, {
    Key? key,
  }) => ProductDetailScreen._(
    title: product.title,
    description: product.description,
    imageUrls: product.imageUrls,
    productUrl: product.productUrl,
    amountMinor: product.amountMinor,
    currency: product.currency,
    category: product.category,
    provider: product.provider,
    externalId: product.externalId,
    merchant: product.merchant,
    listPriceMinor: product.listPriceMinor,
    rating: product.rating,
    reviewCount: product.reviewCount,
    deliveryNote: product.deliveryNote,
    brand: product.brand,
    features: product.features,
    offers: product.offers,
    key: key,
  );

  factory ProductDetailScreen.fromResolved(
    ResolvedUrlProduct product, {
    Key? key,
  }) => ProductDetailScreen._(
    title: product.title,
    description: product.description,
    imageUrls: product.imageUrls,
    productUrl: product.productUrl,
    amountMinor: product.amountMinor,
    currency: product.currency,
    category: null,
    // Only a recognised affiliate network carries provider identity —
    // a scraped page has neither, so it can't go through the import
    // endpoint and falls back to a plain addItem instead.
    provider: product.fromKnownProvider ? product.provider : null,
    externalId: product.fromKnownProvider ? product.externalId : null,
    key: key,
  );

  final String title;
  final String? description;
  final List<String> imageUrls;
  final String productUrl;
  final int? amountMinor;
  final String currency;
  final String? category;
  final String? provider;
  final String? externalId;

  /// Who is selling it. Absent on a scraped page, which has no seller
  /// identity beyond the URL itself.
  final String? merchant;

  /// MRP, struck through beside the price when it is genuinely higher.
  final int? listPriceMinor;

  /// Sparse — most catalogue rows have no rating, so this is hidden rather
  /// than drawn as an empty star row.
  final double? rating;
  final int? reviewCount;

  /// The provider's delivery promise, shown verbatim as theirs.
  final String? deliveryNote;

  final String? brand;

  /// Empty until the detail lookup lands — see [_ProductDetailScreenState].
  final List<ProductFeature> features;
  final List<ProductOffer> offers;

  bool get _isDiscounted =>
      listPriceMinor != null &&
      amountMinor != null &&
      listPriceMinor! > amountMinor!;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _selectedImage = 0;
  bool _busy = false;

  /// What the detail lookup added, once it lands. Null until then — the page
  /// renders from the search result the whole time.
  NormalizedProduct? _enriched;
  bool _enriching = false;

  List<String> get _imageUrls => _enriched?.imageUrls.isNotEmpty ?? false
      ? _enriched!.imageUrls
      : widget.imageUrls;
  List<ProductFeature> get _features => _enriched?.features ?? widget.features;
  List<ProductOffer> get _offers => _enriched?.offers ?? widget.offers;
  double? get _rating => _enriched?.rating ?? widget.rating;
  int? get _reviewCount => _enriched?.reviewCount ?? widget.reviewCount;
  String? get _brand => _enriched?.brand ?? widget.brand;

  @override
  void initState() {
    super.initState();
    unawaited(_enrich());
  }

  /// Fetches the full record in the background.
  ///
  /// Deliberately not awaited before first paint: the lookup is a second
  /// upstream call and takes seconds, and everything a buyer needs to decide
  /// is already on screen from the search. A failure is silent for the same
  /// reason — the page was never incomplete, only less detailed.
  Future<void> _enrich() async {
    final provider = widget.provider;
    final externalId = widget.externalId;
    // A scraped URL has no provider identity, so there is nothing to look up.
    if (provider == null || externalId == null) return;

    setState(() => _enriching = true);
    try {
      final full = await ref
          .read(productRepositoryProvider)
          .details(provider: provider, externalId: externalId);
      if (!mounted) return;
      setState(() {
        _enriched = full;
        _enriching = false;
        // The gallery may have grown or shrunk under us; a stale index would
        // either throw or show the wrong picture.
        _selectedImage = 0;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _enriching = false);
    }
  }

  Future<void> _addToWishlist() async {
    setState(() => _busy = true);
    await ref.read(wishlistsProvider.notifier).ensureLoaded();
    if (!mounted) return;
    final options = ref.read(wishlistsProvider).wishlists ?? const [];

    final chosen = await ChooseWishlistSheet.show(context, options: options);
    setState(() => _busy = false);
    if (chosen == null || !mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => SaveToWishlistScreen(
          wishlist: chosen,
          productTitle: widget.title,
          productSubtitle: widget.description,
          productImageUrl: _imageUrls.isEmpty ? null : _imageUrls.first,
          amountMinor: widget.amountMinor,
          productUrl: widget.productUrl,
          category: widget.category,
          provider: widget.provider,
          externalId: widget.externalId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _busy ? null : _addToWishlist,
                        icon: Icon(Icons.favorite_border, color: colors.accent),
                      ),
                    ],
                  ),
                  AspectRatio(
                    aspectRatio: 1,
                    child: WishtickImage(
                      url: _imageUrls.isEmpty
                          ? null
                          : _imageUrls[_selectedImage],
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  if (_imageUrls.length > 1) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imageUrls.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final selected = index == _selectedImage;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedImage = index),
                            child: Container(
                              width: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                border: Border.all(
                                  color: selected
                                      ? colors.primary
                                      : colors.border,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: WishtickImage(
                                url: _imageUrls[index],
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    widget.title,
                    style: context.text.headlineSmall?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  if (widget.description != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      widget.description!,
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                  // Seller and rating sit between the title and the price, the
                  // order a buyer reads them in: what is it, who is selling
                  // it, is it any good, what does it cost.
                  if (widget.merchant != null || _rating != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        if (widget.merchant != null)
                          Flexible(
                            child: Text(
                              widget.merchant!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodyMedium?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        if (widget.merchant != null && _rating != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: Text(
                              '·',
                              style: context.text.bodyMedium?.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        if (_rating != null)
                          _Rating(rating: _rating!, reviewCount: _reviewCount),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatInrMinor(widget.amountMinor),
                        style: context.text.headlineSmall?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      // Only ever drawn against a genuinely higher MRP — a
                      // struck-through price equal to the real one invents a
                      // saving that does not exist.
                      if (widget._isDiscounted) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            formatInrMinor(widget.listPriceMinor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.priceStruck.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    'Inclusive of all taxes',
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  // The provider's own promise, quoted rather than restated —
                  // re-deriving a date would turn their estimate into ours.
                  if (widget.deliveryNote != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: AppSizes.iconSm,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            widget.deliveryNote!,
                            style: context.text.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Everything below arrives from the detail lookup, so it
                  // appears a beat after the page does. A slim progress line
                  // says more is coming without implying the page is broken.
                  if (_enriching && _offers.isEmpty && _features.isEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: colors.surfaceAlt,
                    ),
                  ],

                  if (_offers.length > 1) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _SectionTitle('Available at ${_offers.length} sellers'),
                    const SizedBox(height: AppSpacing.sm),
                    for (final offer in _offers)
                      _OfferRow(
                        offer: offer,
                        // The first is the cheapest total, which is also
                        // where the buy button goes.
                        best: offer == _offers.first,
                      ),
                  ],

                  if (_features.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _SectionTitle(
                      _brand == null ? 'Details' : 'About this ${_brand!}',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final feature in _features)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 140,
                              child: Text(
                                feature.label,
                                style: context.text.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                feature.value,
                                style: context.text.bodySmall?.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _addToWishlist,
                      child: const Text('Add to Wishlist'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Gifting is coming in a later sprint.',
                                ),
                              ),
                            ),
                      child: const Text('Gift Now'),
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

/// A star, the score, and the review count when the provider gave one.
///
/// Deliberately not five drawn stars: the catalogue reports a single average
/// and no distribution, so a five-star row would be five glyphs standing in
/// for one number — and a half-filled star implies a precision the value does
/// not carry.
class _Rating extends StatelessWidget {
  const _Rating({required this.rating, this.reviewCount});

  final double rating;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = reviewCount;

    return Semantics(
      label: count == null
          ? 'Rated $rating out of 5'
          : 'Rated $rating out of 5 from $count reviews',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: AppSizes.iconSm,
            color: colors.celebration,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            // One decimal, always: "4.0" beside "4.3" reads as a scale, while
            // a bare "4" reads as a different kind of number.
            rating.toStringAsFixed(1),
            style: context.text.bodyMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: AppSpacing.xxs),
            Text(
              '(${formatCount(count)})',
              style: context.text.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.text.titleMedium?.copyWith(
      color: context.colors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
  );
}

/// One seller and its price.
///
/// Not tappable: the buy button already goes to the cheapest, and a row that
/// opened a merchant directly would skip the affiliate wrap, quietly costing
/// the commission that pays for the catalogue.
class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer, required this.best});

  final ProductOffer offer;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              offer.merchant ?? 'Unnamed seller',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: best ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (best) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: colors.successSubtle,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                'Best price',
                style: context.text.labelSmall?.copyWith(
                  color: colors.onSuccessSubtle,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            formatInrMinor(offer.amountMinor),
            style: context.text.bodyMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: best ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
