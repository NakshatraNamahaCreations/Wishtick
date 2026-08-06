import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/currency.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../domain/product.dart';
import 'save_to_wishlist_screen.dart';
import 'widgets/choose_wishlist_sheet.dart';
import 'wishlists_controller.dart';

/// Figma `280:403` — a searched or resolved product, before it's on any
/// wishlist. Ratings/reviews, "Why they'll love it" bullets, "Perfect For",
/// "Recommended Recipients" and "Frequently Gifted Together" all have no
/// backing data (no ratings API, no per-product feature copy, no
/// recommendation engine) and are left out rather than fabricated —
/// gathering who a saved item is for happens for real on
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

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _selectedImage = 0;
  bool _busy = false;

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
          productImageUrl: widget.imageUrls.isEmpty
              ? null
              : widget.imageUrls.first,
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
                      url: widget.imageUrls.isEmpty
                          ? null
                          : widget.imageUrls[_selectedImage],
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  if (widget.imageUrls.length > 1) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.imageUrls.length,
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
                                url: widget.imageUrls[index],
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
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    formatInrMinor(widget.amountMinor),
                    style: context.text.headlineSmall?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Inclusive of all taxes',
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
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
