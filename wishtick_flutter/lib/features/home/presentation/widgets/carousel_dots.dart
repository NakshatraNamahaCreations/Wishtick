import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// The "1/4 • • •" indicator under Home's carousels (Figma `51:11`) — a filled
/// pill carrying the position, then a dot per remaining page.
class CarouselDots extends StatelessWidget {
  const CarouselDots({required this.index, required this.count, super.key});

  final int index;
  final int count;

  static const _dotSize = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (count <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: colors.primaryDeep,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '${index + 1}/$count',
            style: context.text.labelSmall?.copyWith(color: colors.onPrimary),
          ),
        ),
        for (var i = 0; i < count - 1; i++) ...[
          const SizedBox(width: AppSpacing.xs),
          Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
