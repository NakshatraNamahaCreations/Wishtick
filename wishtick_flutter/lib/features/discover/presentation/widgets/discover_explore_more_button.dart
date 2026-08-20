import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// The "Explore More" button under a Discover shelf (`280:131`) — shorter and
/// less rounded than the app-wide [OutlinedButton] theme, with a visibly
/// darker hairline. Sampled off the export at 40px tall against the app's own
/// 54px [AppSizes.buttonHeight], an ~8px radius rather than a pill, and a
/// border close to [WishtickColors.textMuted] rather than the paler
/// [WishtickColors.border] every other outlined button uses.
class DiscoverExploreMoreButton extends StatelessWidget {
  const DiscoverExploreMoreButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  static const _height = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: double.infinity,
      height: _height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.textMuted),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        child: const Text('Explore More'),
      ),
    );
  }
}
