import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/cover_crop_screen.dart';

/// Framing a cover before upload.
///
/// The crop itself is the package's job; what is ours is that the frame is
/// locked to the cover's landscape shape, that backing out uploads nothing,
/// and that the screen stands up in both themes.
void main() {
  /// A valid 4x4 PNG, so the cropper has something real to decode.
  final png = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
    0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x04, // 4x4
    0x08, 0x02, 0x00, 0x00, 0x00, 0x26, 0x93, 0x09, // 8-bit RGB
    0x29, 0x00, 0x00, 0x00, 0x1F, 0x49, 0x44, 0x41, // IDAT (31 bytes)
    0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0xC0,
    0xF0, 0x1F, 0x08, 0xFE, 0x33, 0x30, 0x30, 0xFC,
    0x07, 0x82, 0xFF, 0x0C, 0x0C, 0x0C, 0xFF, 0x81,
    0xE0, 0x3F, 0x03, 0x03, 0x00, 0x8E, 0x8B, 0x0B,
    0x11, 0x2C, 0x06, 0x0B, 0x21, 0x00, 0x00, 0x00, // …
    0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, // IEND
    0x82,
  ]);

  /// Bounded pumps, never settle-until-idle: the cropper decodes the image
  /// off the main isolate and shows a spinner meanwhile, and under the test
  /// binding that decode never lands, so waiting for idle would wait forever
  /// on an animation that is not the thing under test.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Opens the cropper from a host page and hands back the push's future.
  ///
  /// The future is captured, not awaited here: it completes only when the
  /// cropper pops, so awaiting it before tapping anything would wait forever.
  Future<Future<Uint8List?>> open(WidgetTester tester) async {
    Future<Uint8List?>? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => opened = CoverCropScreen.show(context, png),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    return opened!;
  }

  testWidgets('locks the frame to the landscape cover shape', (tester) async {
    await open(tester);

    final crop = tester.widget<Crop>(find.byType(Crop));
    expect(crop.aspectRatio, kCoverAspectRatio);
    expect(kCoverAspectRatio, greaterThan(1), reason: 'landscape');
    // A fixed frame the photo moves under, not a frame the finger reshapes.
    expect(crop.fixCropRect, isTrue);
    expect(find.text('Use this'), findsOneWidget);
  });

  testWidgets('backing out hands back nothing', (tester) async {
    final opened = await open(tester);

    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);

    expect(await opened, isNull);
    expect(find.byType(CoverCropScreen), findsNothing);
  });

  testWidgets('renders on a dark page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CoverCropScreen(image: png),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Frame your cover'), findsOneWidget);
  });
}
