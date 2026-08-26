import 'package:flutter/widgets.dart';

/// The small downward caret that hangs off a selected occasion tile, pointing
/// at its label — Figma `280:584`'s wishlist picker and `257:733`'s event one.
///
/// Anchor it in a `Stack(clipBehavior: Clip.none)` at `bottom: -[overhang]`, so
/// the tip clears the tile and the base stays tucked under its border:
///
/// ```dart
/// Positioned(
///   bottom: -SelectionCaret.overhang,
///   child: SelectionCaret(color: colors.primary),
/// )
/// ```
class SelectionCaret extends StatelessWidget {
  const SelectionCaret({required this.color, super.key});

  /// Measured off the exports; the caret is wider than it is tall.
  static const size = Size(12, 7);

  /// How far below the tile the caret hangs. Less than [size]'s height on
  /// purpose: the remainder sits inside the tile, so the two read as joined
  /// rather than as a triangle floating under a card.
  static const overhang = 5.0;

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: size, painter: _DownCaretPainter(color));
}

class _DownCaretPainter extends CustomPainter {
  const _DownCaretPainter(this.color);

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
  bool shouldRepaint(_DownCaretPainter oldDelegate) =>
      oldDelegate.color != color;
}
