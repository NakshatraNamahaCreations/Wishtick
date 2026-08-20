import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_dimens.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/all_set_screen.dart';

/// Regression test for a `pumpAndSettle` hang: the `confetti` package has no
/// reduced-motion awareness of its own (unlike WishtickSwipeButton's shimmer),
/// so it keeps scheduling frames indefinitely once played regardless of
/// `shouldLoop: false` — the app has to skip playing it at all under reduced
/// motion, both for real accessibility settings and so tests can settle.
void main() {
  Future<ConfettiController> pump(
    WidgetTester tester, {
    required bool reduce,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: const AllSetScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester
        .widget<ConfettiWidget>(find.byType(ConfettiWidget))
        .confettiController;
  }

  testWidgets('plays when motion is allowed', (tester) async {
    final controller = await pump(tester, reduce: false);
    expect(controller.state, ConfettiControllerState.playing);

    // Not pumpAndSettle: the package keeps scheduling frames for the whole
    // burst duration regardless of shouldLoop, so pumpAndSettle would spin
    // until it times out. Advancing past the burst manually proves it stops.
    await tester.pump(AppDurations.confettiBurst);
    expect(controller.state, isNot(ConfettiControllerState.playing));
  });

  testWidgets('never plays when the platform asks for reduced motion', (
    tester,
  ) async {
    final controller = await pump(tester, reduce: true);
    expect(controller.state, ConfettiControllerState.stopped);

    // No burst was started, so this is safe to settle normally — proving the
    // gate, not just working around its absence.
    await tester.pumpAndSettle();
    expect(controller.state, ConfettiControllerState.stopped);
  });

  group('layout (Figma 199:145)', () {
    Future<void> pumpFixedSize(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // Reduced motion: the confetti burst itself is not under test here,
      // and pumpAndSettle needs the tree to actually go quiet.
      await pump(tester, reduce: true);
      await tester.pumpAndSettle();
    }

    testWidgets('no explicit gap sits between the mark and the headline — the '
        "asset's own transparent margin is the gap", (tester) async {
      await pumpFixedSize(tester);

      final markBottom = tester.getBottomLeft(find.byType(Image)).dy;
      final headlineTop = tester.getTopLeft(find.text("You're all set!")).dy;

      expect(headlineTop - markBottom, closeTo(0, 1));
    });

    testWidgets('the button sits 20px in from each edge', (tester) async {
      await pumpFixedSize(tester);

      final button = tester.getRect(find.byType(ElevatedButton));
      expect(button.left, closeTo(20, 1));
      expect(393 - button.right, closeTo(20, 1));
    });

    testWidgets('the button clears the bottom edge by 40px', (tester) async {
      await pumpFixedSize(tester);

      final button = tester.getRect(find.byType(ElevatedButton));
      expect(852 - button.bottom, closeTo(40, 1));
    });
  });
}
