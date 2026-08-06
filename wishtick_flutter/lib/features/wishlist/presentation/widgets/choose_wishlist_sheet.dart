import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../domain/wishlist.dart';

/// Figma `2172:446` — pick one of the caller's own wishlists. Returns the
/// chosen [Wishlist] via `Navigator.pop`, or null if dismissed.
class ChooseWishlistSheet extends StatelessWidget {
  const ChooseWishlistSheet({required this.options, super.key});

  final List<Wishlist> options;

  static Future<Wishlist?> show(
    BuildContext context, {
    required List<Wishlist> options,
  }) {
    return showModalBottomSheet<Wishlist>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ChooseWishlistSheet(options: options),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a wishlist',
              style: context.text.titleLarge?.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (options.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Text(
                  'No other wishlists yet.',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final wishlist = options[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SizedBox(
                        width: 44,
                        height: 44,
                        child: WishtickImage(
                          url: wishlist.coverUrl,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      title: Text(wishlist.title),
                      subtitle: Text('${wishlist.itemCount} items'),
                      onTap: () => Navigator.of(context).pop(wishlist),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
