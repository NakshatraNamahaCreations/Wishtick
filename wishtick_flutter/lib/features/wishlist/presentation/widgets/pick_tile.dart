import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// A selectable quick-pick tile — a photo (occasion) or an icon (relation) —
/// used on the save-to-wishlist screen. Sized by its parent (a [GridView]
/// cell), not by itself, so it fills the column the way Figma `280:584`'s
/// occasion grid does.
class PickTile extends StatelessWidget {
  const PickTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.image,
    super.key,
  }) : assert(
         (image == null) != (icon == null),
         'a tile is either a photo or an icon, never both/neither',
       );

  final IconData? icon;
  final String? image;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final image = this.image;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        color: image == null ? colors.accentSubtle : null,
                        border: selected
                            ? Border.all(color: colors.primary, width: 2)
                            : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: image != null
                          ? Image.asset(image, fit: BoxFit.cover)
                          : Icon(icon, color: colors.primary),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      bottom: -5,
                      child: CustomPaint(
                        size: const Size(12, 7),
                        painter: _DownTrianglePainter(color: colors.primary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: colors.primary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small caret hanging off a selected tile's photo (Figma `280:584`).
class _DownTrianglePainter extends CustomPainter {
  const _DownTrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DownTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
