import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';

/// Figma `288:721` — the celebratory confirmation shown after an item is
/// saved to a wishlist.
class AddedToWishlistScreen extends StatelessWidget {
  const AddedToWishlistScreen({required this.wishlistTitle, super.key});

  final String wishlistTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(Icons.favorite, color: colors.accent, size: 96),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Added to $wishlistTitle',
                textAlign: TextAlign.center,
                style: context.text.headlineMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This product has been added to your wishlist successfully.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('View Wishlist'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Continue shopping'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
