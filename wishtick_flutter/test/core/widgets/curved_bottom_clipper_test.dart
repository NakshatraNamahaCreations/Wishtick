import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/widgets/curved_bottom_clipper.dart';

/// The two mastheads bend opposite ways, and the difference is invisible in a
/// diff — an inverted curve still compiles, still clips, and still looks like
/// "a curved header". These assert the direction against the numbers sampled
/// off the exports.
void main() {
  const size = Size(393, 300);

  /// The clipped foot's y at a fraction across the width.
  ///
  /// Read off the path itself rather than a golden: the question is where the
  /// curve *is*, and a rendered screenshot would answer it far less precisely.
  double footAt(CurvedBottomClipper clipper, double t) {
    final path = clipper.getClip(size);
    final x = size.width * t;
    // Walk down the column and take the last y still inside the shape.
    var last = 0.0;
    for (var y = 0.0; y <= size.height + 40; y += 0.5) {
      if (path.contains(Offset(x.clamp(0.5, size.width - 0.5), y))) last = y;
    }
    return last;
  }

  group('rise — 257:733, the event-creation header', () {
    const clipper = CurvedBottomClipper(
      dip: CurvedBottomClipper.eventRise,
      edge: CurvedBottomEdge.rise,
    );

    testWidgets('the centre sits ABOVE the edges', (tester) async {
      final centre = footAt(clipper, 0.5);
      final edge = footAt(clipper, 0.0);

      // Smaller y is higher up the screen.
      expect(
        centre,
        lessThan(edge),
        reason: 'the plum must end higher in the middle, not lower',
      );
    });

    testWidgets('by the sampled 16px, and the edges reach the full height', (
      tester,
    ) async {
      expect(footAt(clipper, 0.0), closeTo(size.height, 1));
      expect(
        footAt(clipper, 0.5),
        closeTo(size.height - CurvedBottomClipper.eventRise, 1),
      );
    });
  });

  group('sag — the Sprint 11 mastheads', () {
    const clipper = CurvedBottomClipper(dip: CurvedBottomClipper.shallow);

    testWidgets('the centre sits BELOW the edges', (tester) async {
      expect(footAt(clipper, 0.5), greaterThan(footAt(clipper, 0.0)));
    });

    testWidgets('sag is the default, so existing callers are untouched', (
      tester,
    ) async {
      const byDefault = CurvedBottomClipper(dip: CurvedBottomClipper.shallow);
      expect(byDefault.edge, CurvedBottomEdge.sag);
      expect(footAt(byDefault, 0.5), footAt(clipper, 0.5));
    });
  });

  testWidgets('no dip makes the two directions agree on a flat edge', (
    tester,
  ) async {
    const flatSag = CurvedBottomClipper(dip: 0);
    const flatRise = CurvedBottomClipper(dip: 0, edge: CurvedBottomEdge.rise);

    expect(footAt(flatSag, 0.5), closeTo(footAt(flatRise, 0.5), 1));
  });
}
