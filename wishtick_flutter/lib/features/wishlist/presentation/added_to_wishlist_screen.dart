import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../gifting/presentation/widgets/celebration_mark.dart';

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
              // The mock's mark is a magenta heart with a tick through it —
              // the Wishtick logo — surrounded by a confetti burst, same as
              // the order-confirmed and gift-delivered celebrations.
              //
              // [CelebrationMark] reserves a box twice its mark's size so the
              // confetti has room to fly, which — read straight into a
              // Column — pushes the text away by that same empty margin. An
              // [OverflowBox] keeps the burst's full extent but only counts
              // the logo's own 120×120 against layout, closing that gap.
              const SizedBox(
                width: 120,
                height: 120,
                child: OverflowBox(
                  maxWidth: 240,
                  maxHeight: 240,
                  child: CelebrationMark(
                    child: Image(
                      image: AssetImage('assets/logo/logo.png'),
                      width: 120,
                      height: 120,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
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
