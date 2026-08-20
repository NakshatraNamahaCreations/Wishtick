import 'package:flutter/material.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../../wishlist/domain/product.dart';
import '../../../wishlist/presentation/widgets/merchant_label.dart';
import 'discover_explore_more_button.dart';

/// The two-column shelves — "Gifts Under ₹2000" and "Premium Picks for You"
/// (`280:131`) — a plain grid (no per-card fill; items float on the shelf's
/// own background) followed by a full-width "Explore More".
class DiscoverGridShelf extends StatelessWidget {
  const DiscoverGridShelf({
    required this.items,
    required this.onProductTap,
    required this.onSave,
    required this.onExplore,
    super.key,
  });

  final List<NormalizedProduct> items;
  final ValueChanged<NormalizedProduct> onProductTap;
  final ValueChanged<NormalizedProduct> onSave;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.xxl,
            mainAxisSpacing: AppSpacing.xxxl,
            // Tuned to the tile's own content (square image, one title line,
            // a price line, a badge row) rather than measured directly — the
            // export gives pixel widths, not a ratio.
            childAspectRatio: 0.62,
          ),
          itemBuilder: (context, index) {
            final product = items[index];
            return _GridProductTile(
              product: product,
              onTap: () => onProductTap(product),
              onSave: () => onSave(product),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        DiscoverExploreMoreButton(onPressed: onExplore),
      ],
    );
  }
}

class _GridProductTile extends StatelessWidget {
  const _GridProductTile({
    required this.product,
    required this.onTap,
    required this.onSave,
  });

  final NormalizedProduct product;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final merchant = product.merchant ?? merchantLabel(product.productUrl);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: WishtickImage(
              url: product.coverImageUrl,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              Text(
                formatInrMinor(product.amountMinor),
                style: AppTypography.price.copyWith(color: colors.textPrimary),
              ),
              if (product.isDiscounted) ...[
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    formatInrMinor(product.listPriceMinor),
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
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(child: _BrandBadge(merchant: merchant)),
              _SaveButton(onTap: onSave),
            ],
          ),
        ],
      ),
    );
  }
}

/// The merchant row under a grid tile's price.
///
/// A logo asset is only wired up for the three retailers the export shows
/// (Amazon, Myntra, Flipkart) — cropped directly from `280:131` rather than
/// invented, since no brand-logo assets shipped with the app. Any other
/// merchant `merchantLabel` recognises falls back to its plain text label,
/// same as before this shelf existed.
class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.merchant});

  final String? merchant;

  @override
  Widget build(BuildContext context) {
    final merchant = this.merchant;
    if (merchant == null) return const SizedBox.shrink();

    final colors = context.colors;
    final label = Text(
      merchant,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.bodySmall?.copyWith(color: colors.textSecondary),
    );

    // Amazon's crop is a wordmark — it already carries its own name, so no
    // separate text label is drawn alongside it.
    final logo = switch (merchant) {
      'Amazon' => Image.asset('assets/icons/amazon_badge.png', height: 14),
      'Myntra' => Image.asset('assets/icons/myntra_badge.png', height: 16),
      'Flipkart' => Image.asset('assets/icons/flipkart_badge.png', height: 18),
      _ => null,
    };

    if (logo == null) return label;
    if (merchant == 'Amazon') return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: AppSpacing.xxs),
        Flexible(child: label),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});

  final VoidCallback onTap;

  static const _size = 32.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: 'Save to a wishlist',
      child: Material(
        color: colors.primaryDeep,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: SizedBox(
            width: _size,
            height: _size,
            child: Icon(
              Icons.favorite_border,
              size: AppSizes.iconSm,
              color: colors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
