import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/splash/presentation/particle_text.dart';

import '../../helpers/load_app_fonts.dart';

const _key = ValueKey('capture');
const _style = TextStyle(
  fontFamily: 'Montserrat',
  fontSize: 40,
  color: Color(0xFFFFFFFF),
);

/// Ink coverage of a rendered frame: how many pixels were painted, and the
/// box they occupy.
///
/// The box is the interesting half. Particles in flight sit *outside* the
/// letterforms, so a mid-animation frame covers a visibly larger area than the
/// settled word — which is what distinguishes a real particle effect from a
/// plain fade that happens to be halfway through.
typedef _Ink = ({int pixels, Rect bounds});

Future<_Ink> _measureInk(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
  final image = await boundary.toImage();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final width = image.width;
  final height = image.height;
  image.dispose();

  final pixels = data!.buffer.asUint8List();
  var count = 0;
  var minX = width, minY = height, maxX = -1, maxY = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (pixels[(y * width + x) * 4 + 3] > 40) {
        count++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  return (
    pixels: count,
    bounds: maxX < 0
        ? Rect.zero
        : Rect.fromLTRB(
            minX.toDouble(),
            minY.toDouble(),
            maxX.toDouble(),
            maxY.toDouble(),
          ),
  );
}

/// Ink that has *landed*, counted in eighths across the width of the word.
///
/// Only the band of rows the finished text occupies is counted, so particles
/// still circling above and below their targets are excluded — what is left is
/// a profile of how much of each part of the word has actually formed.
Future<List<int>> _landedPerEighth(WidgetTester tester) async {
  final textWidth = tester.getSize(find.text('Wishtick')).width;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
  final image = await boundary.toImage();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final width = image.width;
  final height = image.height;
  image.dispose();

  final pixels = data!.buffer.asUint8List();
  final left = ((width - textWidth) / 2).round();
  final band = tester.getSize(find.text('Wishtick')).height;
  final top = ((height - band) / 2).round();

  final buckets = List<int>.filled(8, 0);
  for (var y = top; y < top + band; y++) {
    for (var x = 0; x < width; x++) {
      if (pixels[(y * width + x) * 4 + 3] > 60) {
        final rel = (x - left) / textWidth;
        if (rel >= 0 && rel < 1) buckets[(rel * 8).floor().clamp(0, 7)]++;
      }
    }
  }
  return buckets;
}

/// Pumps a [ParticleText] whose progress this test drives by hand.
Future<AnimationController> _pumpParticleText(
  WidgetTester tester, {
  required bool animations,
}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: !animations);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final controller = AnimationController(
    vsync: const TestVSync(),
    duration: const Duration(seconds: 1),
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Center(
          // Padded so the capture takes in the space the cloud flies through:
          // toImage() only records the boundary's own bounds, and the scatter
          // reaches well outside the word.
          child: RepaintBoundary(
            key: _key,
            child: Padding(
              padding: const EdgeInsets.all(120),
              child: ParticleText(
                text: 'Wishtick',
                style: _style,
                animation: controller,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  testWidgets('particles land on the letterforms, not merely near them', (
    tester,
  ) async {
    late _Ink inFlight;
    late _Ink settled;

    // runAsync throughout: the glyph raster and every capture below are real
    // engine work, which the fake-async test clock will not drive on its own.
    await tester.runAsync(() async {
      final controller = await _pumpParticleText(tester, animations: true);

      // Let the offscreen rasterise-and-sample finish and reach setState.
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      expect(
        find.byType(CustomPaint),
        findsWidgets,
        reason: 'the particle layer should be mounted once sampling completes',
      );

      controller.value = 0.3;
      await tester.pump();
      inFlight = await _measureInk(tester);

      controller.value = 1;
      await tester.pump();
      settled = await _measureInk(tester);
    });

    expect(inFlight.pixels, greaterThan(0), reason: 'nothing was drawn');
    expect(settled.pixels, greaterThan(0), reason: 'the word never resolved');

    // The scatter reaches 18–96px off each target, so mid-flight ink spills
    // well beyond the final word on both axes.
    expect(
      inFlight.bounds.width,
      greaterThan(settled.bounds.width + 20),
      reason: 'particles should still be spread wider than the finished word',
    );
    expect(
      inFlight.bounds.height,
      greaterThan(settled.bounds.height + 20),
      reason: 'particles should still be spread taller than the finished word',
    );
  });

  testWidgets('the word assembles letter by letter, not all at once', (
    tester,
  ) async {
    late List<List<int>> profiles;

    await tester.runAsync(() async {
      final controller = await _pumpParticleText(tester, animations: true);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pump();

      profiles = [];
      for (final at in [0.15, 0.3, 0.45, 0.6]) {
        controller.value = at;
        await tester.pump();
        profiles.add(await _landedPerEighth(tester));
      }
    });

    // Each column is one eighth of the word, left to right. If letters form in
    // order, the left eighths are populated at 0.15 while the right ones are
    // still largely empty, and the frontier marches right from frame to frame.
    int frontier(List<int> profile) {
      final full = profile.reduce(math.max);
      var last = -1;
      for (var i = 0; i < profile.length; i++) {
        if (profile[i] > full * 0.6) last = i;
      }
      return last;
    }

    final frontiers = profiles.map(frontier).toList();
    for (var i = 1; i < frontiers.length; i++) {
      expect(
        frontiers[i],
        greaterThanOrEqualTo(frontiers[i - 1]),
        reason:
            'the formed region should only ever grow rightwards: $frontiers',
      );
    }
    expect(
      frontiers.first,
      lessThan(frontiers.last),
      reason: 'the whole word formed at once — no letter ordering: $frontiers',
    );
    expect(
      frontiers.first,
      lessThan(6),
      reason: 'the right of the word was already formed early: $frontiers',
    );
  });

  testWidgets('the word is crisp at the end — no particles left over', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = await _pumpParticleText(tester, animations: true);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      controller.value = 1;
      await tester.pump();
      final settled = await _measureInk(tester);

      // At rest the ink must fit the text box itself. Any stray dot outside it
      // would mean the cloud had not fully dissolved into the glyphs.
      final textSize = tester.getSize(find.text('Wishtick'));
      expect(settled.bounds.width, lessThanOrEqualTo(textSize.width + 2));
      expect(settled.bounds.height, lessThanOrEqualTo(textSize.height + 2));
    });
  });

  testWidgets('the words are readable to semantics from the first frame', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await _pumpParticleText(tester, animations: true);
      await tester.pump();

      // The real Text is only transparent, never absent — a screen reader and
      // `find.text` see the word while the cloud is still forming it.
      expect(find.text('Wishtick'), findsOneWidget);
    });
  });

  testWidgets('reduce motion renders plain text with no particle layer', (
    tester,
  ) async {
    await _pumpParticleText(tester, animations: false);
    await tester.pump();

    expect(find.text('Wishtick'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(_key), matching: find.byType(CustomPaint)),
      findsNothing,
      reason: 'no cloud should be built at all under reduce motion',
    );
  });
}
