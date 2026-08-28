import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/auth/presentation/welcome_screen.dart';

/// The welcome artwork, checked against the code that points at it.
///
/// These four images are the whole screen — headline, body and the only button
/// are all pixels — so the app's single interactive element is a rect measured
/// off the picture. That is a hard thing to keep true: re-export one image with
/// the button a little lower and the app still builds, still passes every
/// widget test, and simply stops working, with a dead area where the button
/// looks like it is.
///
/// So this decodes the *shipped* assets and re-measures them. It is the only
/// test here that would notice.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The plum the buttons are drawn in, allowing for WebP's slight shifts.
  bool isPlum(int r, int g, int b) =>
      r > 60 && r < 110 && g < 55 && b > 80 && b < 135;

  Future<ui.Image> decode(String assetPath) async {
    final bytes = await File(assetPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }

  for (final slide in WelcomeScreen.slides) {
    test(
      '${slide.figmaNodeId}: the hit area lands on the drawn button',
      () async {
        final image = await decode(slide.asset);
        addTearDown(image.dispose);

        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        expect(data, isNotNull, reason: '${slide.asset} would not decode');
        final pixels = data!.buffer.asUint8List();

        int at(int x, int y) => (y * image.width + x) * 4;
        bool plumAt(double fx, double fy) {
          final x = (fx * (image.width - 1)).round();
          final y = (fy * (image.height - 1)).round();
          final i = at(x, y);
          return isPlum(pixels[i], pixels[i + 1], pixels[i + 2]);
        }

        // A grid across the declared rect, requiring most of it to be plum.
        //
        // Most, not all: each button carries a white label and some an icon, so
        // samples legitimately land on glyphs. What this catches is a rect that
        // has slid off the button onto the photograph — where the plum share
        // collapses rather than dipping.
        var plum = 0;
        var total = 0;
        for (var i = 1; i <= 8; i++) {
          for (var j = 1; j <= 4; j++) {
            final x = slide.button.left + (i / 9) * slide.button.width;
            final y = slide.button.top + (j / 5) * slide.button.height;
            total++;
            if (plumAt(x, y)) plum++;
          }
        }

        expect(
          plum / total,
          greaterThan(0.7),
          reason:
              '${slide.asset}: only $plum of $total samples inside the declared '
              'hit area are on a plum button. Re-measure WelcomeSlide.button '
              'for this slide.',
        );
      },
    );
  }

  test('every slide ships as WebP, not the source PNG', () {
    for (final slide in WelcomeScreen.slides) {
      // The source exports are ~7 MB each; the WebP versions are ~430 KB for
      // the same pixels. Pointing a slide back at a PNG would put 29 MB of
      // artwork into the download for four screens seen once.
      expect(
        slide.asset,
        endsWith('.webp'),
        reason: '${slide.figmaNodeId} points at a non-WebP asset',
      );
      expect(File(slide.asset).existsSync(), isTrue, reason: slide.asset);
      expect(
        File(slide.asset).lengthSync(),
        lessThan(1024 * 1024),
        reason: '${slide.asset} is over 1 MB — re-encode it',
      );
    }
  });

  test(
    'the declared aspect ratio matches what the artwork was drawn at',
    () async {
      for (final slide in WelcomeScreen.slides) {
        final image = await decode(slide.asset);
        addTearDown(image.dispose);
        // The hit-area maths converts fractions of the *artwork* into screen
        // pixels using this ratio. A slide drawn at a different shape would put
        // the button somewhere else entirely.
        expect(
          image.width / image.height,
          closeTo(WelcomeScreen.artworkAspectRatio, 0.001),
          reason: '${slide.asset} is ${image.width}x${image.height}',
        );
      }
    },
  );
}
