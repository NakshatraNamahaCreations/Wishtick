import 'package:flutter/material.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../domain/wishlist_item.dart';
import 'merchant_label.dart';

/// One tile in the wishlist detail's item grid — Figma `280:212`.
class WishlistItemCard extends StatelessWidget {
  const WishlistItemCard({
    required this.item,
    required this.onTap,
    this.onDelete,
    super.key,
  });

  final WishlistItem item;
  final VoidCallback onTap;

  /// Null on a list you do not own — removing someone else's item is an owner
  /// action the server refuses, so the button is not drawn at all.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final merchant = merchantLabel(item.productLink);

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
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: WishtickImage(
                        url: item.coverImageUrl,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    if (onDelete != null)
                      Positioned(
                        right: AppSpacing.xs,
                        bottom: AppSpacing.xs,
                        child: _DeleteButton(onTap: onDelete!),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                formatInrMinor(item.price.amountMinor),
                style: AppTypography.price.copyWith(color: colors.textPrimary),
              ),
              if (merchant != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  merchant,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap});

  final VoidCallback onTap;

  static const _size = 32.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.primaryDeep,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Icon(
            Icons.delete_outline,
            color: colors.onPrimary,
            size: AppSizes.iconSm,
          ),
        ),
      ),
    );
  }
}
