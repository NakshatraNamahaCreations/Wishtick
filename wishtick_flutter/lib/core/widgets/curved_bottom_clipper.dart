import 'package:flutter/widgets.dart';

/// Which way a masthead's foot bends.
///
/// The two are not the same curve at different depths — they are mirror
/// images, which is why no value of [CurvedBottomClipper.dip] turns one into
/// the other. Under [sag] the centre is always the lowest point; under [rise]
/// it is always the highest.
enum CurvedBottomEdge {
  /// The centre hangs below the edges — the Sprint 11 mastheads.
  sag,

  /// The edges hang below the centre — `257:733`'s event-creation header.
  rise,
}

/// The sweep along a plum masthead's foot.
///
/// Shared rather than copied per screen: it is a bezier, and a bezier written
/// twice is two curves that drift.
///
/// [dip] is the distance between the curve's high and low points; [edge]
/// decides which of those the centre is. Measured off the exports:
/// `4177:77`'s plum ends at y 122 at both edges and y 129 at the centre — a
/// 7-px [sag]. `257:733` is the other way about: y 268 at the edges and y 252
/// at the centre, a 16-px [rise].
class CurvedBottomClipper extends CustomClipper<Path> {
  const CurvedBottomClipper({
    this.dip = deep,
    this.edge = CurvedBottomEdge.sag,
  });

  /// Kept for callers that already ask for it by name.
  static const deep = 28.0;

  /// The Sprint 11 headers' barely-there sag, measured off the exports.
  static const shallow = 7.0;

  /// `257:733`'s arc, which bends the opposite way — see [CurvedBottomEdge].
  static const eventRise = 16.0;

  final double dip;
  final CurvedBottomEdge edge;

  @override
  Path getClip(Size size) {
    final path = Path();
    switch (edge) {
      case CurvedBottomEdge.sag:
        // Edges lifted by `dip`, centre landing exactly on the bottom.
        path
          ..lineTo(0, size.height - dip)
          ..quadraticBezierTo(
            size.width / 2,
            size.height + dip,
            size.width,
            size.height - dip,
          );
      case CurvedBottomEdge.rise:
        // Edges on the bottom, centre lifted by `dip`. The control point sits
        // at twice the dip because a quadratic reaches only half way to it.
        path
          ..lineTo(0, size.height)
          ..quadraticBezierTo(
            size.width / 2,
            size.height - dip * 2,
            size.width,
            size.height,
          );
    }
    return path
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CurvedBottomClipper oldClipper) =>
      oldClipper.dip != dip || oldClipper.edge != edge;
}
