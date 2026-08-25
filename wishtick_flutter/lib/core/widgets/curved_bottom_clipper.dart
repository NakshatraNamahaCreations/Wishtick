import 'package:flutter/widgets.dart';

/// The concave sweep along a plum masthead's foot.
///
/// Shared rather than copied per screen: it is a bezier, and a bezier written
/// twice is two curves that drift. `257:733` draws it deep; the Sprint 11
/// frames (`4177:77`, `4177:111`, `4177:42`, `4177:179`) draw the same shape
/// much shallower, which is the only thing [dip] changes.
///
/// [dip] is how far the *edges* rise above the box's bottom; the centre of the
/// curve lands exactly on it. Sampling `4177:77` bears that out — the plum ends
/// at y 122 at both edges and y 129 at the centre, a 7-px sag.
class CurvedBottomClipper extends CustomClipper<Path> {
  const CurvedBottomClipper({this.dip = deep});

  /// `257:733`'s sweep — the deep one the event-creation header uses.
  static const deep = 28.0;

  /// The Sprint 11 headers' barely-there sag, measured off the exports.
  static const shallow = 7.0;

  final double dip;

  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - dip)
      ..quadraticBezierTo(
        size.width / 2,
        size.height + dip,
        size.width,
        size.height - dip,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CurvedBottomClipper oldClipper) =>
      oldClipper.dip != dip;
}
