import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/theme_extensions.dart';

/// Inline form/flow error message.
///
/// Announced to assistive tech via [Semantics.liveRegion] so a screen reader
/// reports a failed submit without the user hunting for it.
class WishtickErrorText extends StatelessWidget {
  const WishtickErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: AppSizes.iconMd,
            color: colors.danger,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: context.text.bodySmall?.copyWith(color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
