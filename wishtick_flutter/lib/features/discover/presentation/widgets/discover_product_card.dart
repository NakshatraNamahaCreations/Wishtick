import 'package:flutter/material.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../../wishlist/domain/product.dart';
import '../../../wishlist/presentation/widgets/merchant_label.dart';

/// A product tile on Discover (Figma `280:131`) — image, title, price with the
/// MRP struck through when there is a real discount, merchant, and a
/// save-to-wishlist button.
class DiscoverProductCard extends StatelessWidget {
  const DiscoverProductCard({
    required this.product,
    required this.onTap,
    required this.onSave,
    this.showSaveButton = true,
    super.key,
  });

  final NormalizedProduct product;
  final VoidCallback onTap;
  final VoidCallback onSave;

  /// The per-person shelves in the mock show a bare card; the grid shows the
  /// save button.
  final bool showSaveButton;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The provider's own merchant name if it gave one, else derived from the
    // product URL's host.
    final merchant = product.merchant ?? merchantLabel(product.productUrl);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: WishtickImage(
                  url: product.coverImageUrl,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                product.title,
                maxLines: 2,
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
                    style: AppTypography.price.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  // Only shown when the backend gave a genuinely higher list
                  // price — never a fabricated saving.
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
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      merchant ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  if (showSaveButton) _SaveButton(onTap: onSave),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});

  final VoidCallback onTap;

  static const _size = 30.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'Save to a wishlist',
      child: Material(
        color: colors.primaryDeep,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
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
