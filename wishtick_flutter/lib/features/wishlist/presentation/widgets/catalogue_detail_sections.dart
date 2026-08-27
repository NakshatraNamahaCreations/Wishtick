/// The catalogue detail a saved wishlist item's own snapshot never carried.
///
/// An imported item keeps a copy of the title, price and image as they were at
/// import, deliberately frozen. Everything here — the gallery, the seller, the
/// rating, the other sellers, the specification table — is fetched fresh from
/// the catalogue row the item came from, and is absent for an item added by
/// hand, which has no catalogue row at all.
///
/// Written against the same frame as the search-side product page so the two
/// read alike; that screen keeps its own private copies rather than these
/// being lifted out of it, because it is owned elsewhere right now.
library;

import 'package:flutter/material.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../domain/product.dart';

/// The image gallery: one large image with a thumbnail strip under it.
class CatalogueGallery extends StatefulWidget {
  const CatalogueGallery({required this.imageUrls, super.key});

  final List<String> imageUrls;

  @override
  State<CatalogueGallery> createState() => _CatalogueGalleryState();
}

class _CatalogueGalleryState extends State<CatalogueGallery> {
  int _selected = 0;

  @override
  void didUpdateWidget(CatalogueGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The gallery grows when the catalogue lookup lands, and a stale index
    // would either throw or show the wrong picture.
    if (widget.imageUrls.length != oldWidget.imageUrls.length) _selected = 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final urls = widget.imageUrls;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: WishtickImage(
            url: urls.isEmpty
                ? null
                : urls[_selected.clamp(0, urls.length - 1)],
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        // One picture is not a gallery, and a strip of exactly one thumbnail
        // under it reads as a bug rather than a choice.
        if (urls.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final selected = index == _selected;
                return GestureDetector(
                  onTap: () => setState(() => _selected = index),
                  child: Container(
                    width: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: selected ? colors.primary : colors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: WishtickImage(
                      url: urls[index],
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// "Amazon.in · ★ 4.0 (165)" — who sells it and what it scored.
///
/// Both halves are sparse in the catalogue, so each is dropped on its own
/// rather than the row being drawn half-empty.
class SellerRatingLine extends StatelessWidget {
  const SellerRatingLine({
    required this.merchant,
    required this.rating,
    required this.reviewCount,
    super.key,
  });

  final String? merchant;
  final double? rating;
  final int? reviewCount;

  bool get hasAnything => merchant != null || rating != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        if (merchant != null)
          Flexible(
            child: Text(
              merchant!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        if (merchant != null && rating != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              '·',
              style: context.text.bodyMedium?.copyWith(color: colors.textMuted),
            ),
          ),
        if (rating != null) ...[
          Icon(Icons.star, size: AppSizes.iconSm, color: colors.warning),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            rating!.toStringAsFixed(1),
            style: context.text.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
          if (reviewCount != null) ...[
            const SizedBox(width: AppSpacing.xxs),
            Text(
              '($reviewCount)',
              style: context.text.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ],
        ],
      ],
    );
  }
}

/// The price, with the MRP struck through beside it when there is a real one.
class CataloguePrice extends StatelessWidget {
  const CataloguePrice({
    required this.amountMinor,
    required this.listPriceMinor,
    super.key,
  });

  final int? amountMinor;
  final int? listPriceMinor;

  /// A struck-through price equal to the real one invents a saving that does
  /// not exist, so the MRP is drawn only when it is genuinely higher.
  bool get _isDiscounted =>
      listPriceMinor != null &&
      amountMinor != null &&
      listPriceMinor! > amountMinor!;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatInrMinor(amountMinor),
              style: context.text.headlineSmall?.copyWith(
                color: colors.textPrimary,
              ),
            ),
            if (_isDiscounted) ...[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  formatInrMinor(listPriceMinor),
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
          style: context.text.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

/// The provider's own delivery promise, quoted rather than restated —
/// re-deriving a date would turn their estimate into ours.
class DeliveryNote extends StatelessWidget {
  const DeliveryNote({required this.note, super.key});

  final String note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(
          Icons.local_shipping_outlined,
          size: AppSizes.iconSm,
          color: colors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            note,
            style: context.text.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class CatalogueSectionTitle extends StatelessWidget {
  const CatalogueSectionTitle(this.text, {super.key});

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

/// One seller under "Available at N sellers".
class CatalogueOfferRow extends StatelessWidget {
  const CatalogueOfferRow({
    required this.offer,
    required this.best,
    required this.onTap,
    super.key,
  });

  final ProductOffer offer;
  final bool best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        // The bare text height is under the 48px minimum for a tap target.
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
            // The row leaves the app, so it says so.
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.open_in_new,
              size: AppSizes.iconSm,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The label/value specification table.
class CatalogueFeatureTable extends StatelessWidget {
  const CatalogueFeatureTable({required this.features, super.key});

  final List<ProductFeature> features;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final feature in features)
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
    );
  }
}
