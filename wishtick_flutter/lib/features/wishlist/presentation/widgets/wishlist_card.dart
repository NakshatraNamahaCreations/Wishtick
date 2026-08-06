import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../domain/wishlist.dart';

/// One row on the "My Wishlist" tab — cover, title, "Visibility · N items",
/// chevron.
class WishlistCard extends StatelessWidget {
  const WishlistCard({required this.wishlist, required this.onTap, super.key});

  final Wishlist wishlist;
  final VoidCallback onTap;

  static const _thumbSize = 64.0;

  static String _visibilityLabel(WishlistVisibility v) => switch (v) {
    WishlistVisibility.public => 'Public',
    WishlistVisibility.private => 'Private',
    WishlistVisibility.eventOnly => 'Event',
    WishlistVisibility.inviteOnly => 'Invite only',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final itemWord = wishlist.itemCount == 1 ? 'item' : 'items';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              SizedBox(
                width: _thumbSize,
                height: _thumbSize,
                child: WishtickImage(
                  url: wishlist.coverUrl,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      wishlist.title,
                      style: context.text.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${_visibilityLabel(wishlist.visibility)} · ${wishlist.itemCount} $itemWord',
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colors.textMuted,
                size: AppSizes.iconMd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
