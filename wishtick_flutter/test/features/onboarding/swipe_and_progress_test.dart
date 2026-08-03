import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_colors.dart';
import 'package:wishtick_flutter/core/theme/app_dimens.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_swipe_button.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/widgets/onboarding_progress.dart';

import '../../helpers/load_app_fonts.dart';
import '../../helpers/swipe.dart';

/// The swipe-to-continue control and the filling progress heart, driven
/// directly rather than through a screen, so each behaviour is pinned on its
/// own terms.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  /// [settle] is off for the busy case: a spinner animates forever, so
  /// pumpAndSettle would never return.
  Future<void> pumpHarness(
    WidgetTester tester,
    Widget child, {
    bool settle = true,
  }) async {
    tester.view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenGutter,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  /// Left edge of the gold knob, which is the only thing that moves while
  /// idle/dragging.
  double knobLeft(WidgetTester tester) => tester
      .getRect(
        find.descendant(
          of: find.byType(WishtickSwipeButton),
          matching: find.byIcon(Icons.chevron_right),
        ),
      )
      .left;

  group('swipe to continue', () {
    testWidgets('the idle knob carries an arrow, not a check', (tester) async {
      await pumpHarness(
        tester,
        WishtickSwipeButton(onSwiped: () async => true),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    // `tester.drag()` fires a whole synthetic gesture with no rebuild in
    // between the simulated pointer moves, so it cannot catch a recognizer
    // that gets torn down mid-gesture by a rebuild the drag itself triggers —
    // exactly what happened on a real device: the callbacks were wired to
    // `enabled`, which flips false the instant the first update sets phase to
    // `dragging`, and Flutter drops a GestureDetector callback that goes null
    // by disposing its recognizer, killing the gesture after one pixel. This
    // drives a real multi-frame gesture — down, several moves each followed
    // by a pump (so setState-triggered rebuilds actually happen in between,
    // as they do on a device), then up — to prove the drag survives them.
    testWidgets(
      'a real multi-frame drag (with rebuilds between moves) still commits',
      (tester) async {
        var fired = 0;
        await pumpHarness(
          tester,
          WishtickSwipeButton(
            onSwiped: () async {
              fired++;
              return true;
            },
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(WishtickSwipeButton)),
        );
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(50, 0));
          // The rebuild a real frame would produce between touch events —
          // this is the step `tester.drag()` skips.
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();

        expect(
          fired,
          1,
          reason:
              'the drag must survive rebuilds triggered mid-gesture by its '
              'own setState calls, not just an atomic synthetic drag',
        );

        // Drain the collapse + success dwell, same blind spot pumpAndSettle
        // has everywhere else in this file — a bare Future.delayed with no
        // active ticker won't get pumped past by pumpAndSettle alone.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(AppDurations.successDwell);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('a completed swipe collapses to a spinner, then a check, then '
        'calls onSuccess', (tester) async {
      var fired = 0;
      var succeeded = 0;
      final completer = Completer<bool>();
      await pumpHarness(
        tester,
        WishtickSwipeButton(
          onSwiped: () {
            fired++;
            return completer.future;
          },
          onSuccess: () => succeeded++,
        ),
        settle: false,
      );

      await tester.drag(find.byType(WishtickSwipeButton), const Offset(500, 0));
      // Let the collapse animation finish so the spinner is actually up.
      await tester.pump(const Duration(milliseconds: 300));

      expect(fired, 1);
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'the track should collapse to a spinner while awaited',
      );
      expect(find.text('Swipe to continue'), findsNothing);
      expect(succeeded, 0, reason: 'not resolved yet');

      completer.complete(true);
      await tester.pump(); // let the Future resolve
      await tester.pump(); // enter the success phase

      expect(
        find.byIcon(Icons.check),
        findsOneWidget,
        reason: 'success should show a check in the same circle',
      );
      expect(succeeded, 0, reason: 'still dwelling on the check');

      await tester.pump(AppDurations.successDwell);
      expect(succeeded, 1);
    });

    testWidgets('a swipe that resolves false springs back with no onSuccess', (
      tester,
    ) async {
      var succeeded = 0;
      await pumpHarness(
        tester,
        WishtickSwipeButton(
          onSwiped: () async => false,
          onSuccess: () => succeeded++,
        ),
      );

      final resting = knobLeft(tester);
      await swipeToContinue(tester);

      expect(succeeded, 0);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(knobLeft(tester), moreOrLessEquals(resting, epsilon: 1));
    });

    testWidgets('a swipe that stops short springs back without firing', (
      tester,
    ) async {
      var fired = 0;
      await pumpHarness(
        tester,
        WishtickSwipeButton(
          onSwiped: () async {
            fired++;
            return true;
          },
        ),
      );

      final resting = knobLeft(tester);
      await swipePartway(tester);

      expect(fired, 0, reason: 'a half-hearted drag must not submit');
      expect(knobLeft(tester), moreOrLessEquals(resting, epsilon: 1));
    });

    testWidgets('a disabled track ignores a full swipe', (tester) async {
      await pumpHarness(tester, const WishtickSwipeButton(onSwiped: null));

      final resting = knobLeft(tester);
      await swipeToContinue(tester);

      expect(knobLeft(tester), moreOrLessEquals(resting, epsilon: 1));
    });

    testWidgets('mid-swipe refuses a second swipe', (tester) async {
      var fired = 0;
      final completer = Completer<bool>();
      await pumpHarness(
        tester,
        WishtickSwipeButton(
          onSwiped: () {
            fired++;
            return completer.future;
          },
        ),
        settle: false,
      );

      await tester.drag(find.byType(WishtickSwipeButton), const Offset(500, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fired, 1);

      // The track is now a collapsed circle, not draggable — this should be
      // a no-op, not a second submission.
      await tester.drag(find.byType(WishtickSwipeButton), const Offset(500, 0));
      await tester.pump();
      expect(fired, 1, reason: 'must not double-submit while processing');

      // Not pumpAndSettle: the success dwell is a bare timer with nothing
      // animating, so pumpAndSettle would stop pumping before it ever fires.
      completer.complete(true);
      await tester.pump();
      await tester.pump(AppDurations.successDwell);
      await tester.pumpAndSettle();
    });

    // The rest of the suite runs reduced-motion (see flutter_test_config.dart),
    // so without this the shimmer path would never be exercised at all.
    testWidgets('the sheen runs only when motion is allowed', (tester) async {
      Widget wrap({required bool reduce}) => MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: Scaffold(
            body: WishtickSwipeButton(onSwiped: () async => true),
          ),
        ),
      );

      await tester.pumpWidget(wrap(reduce: false));
      await tester.pump();
      expect(
        find.byType(ShaderMask),
        findsOneWidget,
        reason: 'the label should be masked by a travelling sheen',
      );
      // Deliberately not pumpAndSettle: the sweep repeats by design.
      await tester.pump(const Duration(milliseconds: 300));

      // Switching motion off stops it — and leaves no ticker running at the
      // end of the test.
      await tester.pumpWidget(wrap(reduce: true));
      await tester.pumpAndSettle();
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('it is still an activatable button for assistive tech', (
      tester,
    ) async {
      var fired = 0;
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        WishtickSwipeButton(
          onSwiped: () async {
            fired++;
            return true;
          },
        ),
      );

      // A screen-reader user cannot perform a drag, so the semantic tap has to
      // reach the same action.
      tester.semantics.performAction(
        find.semantics.byLabel('Swipe to continue'),
        SemanticsAction.tap,
      );
      // Not pumpAndSettle: the success dwell is a bare timer with nothing
      // animating, so pumpAndSettle would stop pumping before it ever fires.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260)); // collapse
      await tester.pump(AppDurations.successDwell);
      await tester.pumpAndSettle();

      expect(fired, 1);
      handle.dispose();
    });
  });

  group('HeartFillGeometry (the area-vs-height calibration)', () {
    // The whole point of this table: it must NOT be the identity function.
    // Naive height == area was exactly the bug ("80% looked full" at step 4).
    test('reveals meaningfully more height than a naive fraction would', () {
      final naive = 0.4;
      final calibrated = HeartFillGeometry.heightFractionForArea(naive);

      expect(
        calibrated,
        isNot(moreOrLessEquals(naive, epsilon: 0.05)),
        reason:
            'a heart is narrow at the bottom, so revealing 40% of its AREA '
            'needs climbing well past 40% of its HEIGHT — if this ever '
            'equals the input, the calibration has been bypassed',
      );
      expect(
        calibrated,
        greaterThan(naive),
        reason:
            'the bottom point is area-poor, so area accumulates slower '
            'than height — the calibrated height must be the larger one',
      );
    });

    test('0% area needs no height, 100% area needs the full height', () {
      expect(HeartFillGeometry.heightFractionForArea(0), 0.0);
      expect(
        HeartFillGeometry.heightFractionForArea(1),
        moreOrLessEquals(1.0, epsilon: 0.01),
      );
    });

    test('is monotonically non-decreasing', () {
      var previous = 0.0;
      for (var area = 0.0; area <= 1.0; area += 0.05) {
        final height = HeartFillGeometry.heightFractionForArea(area);
        expect(
          height,
          greaterThanOrEqualTo(previous),
          reason: 'more area requested must never need less height',
        );
        previous = height;
      }
    });
  });

  group('progress heart', () {
    HeartPainter painterFor(WidgetTester tester) =>
        tester.widget<CustomPaint>(find.byKey(progressHeartKey)).painter!
            as HeartPainter;

    // One less than the bar: the heart shows steps *completed*, so it reads
    // 0% while working on step 1 and only reaches 80% on step 5 — the last
    // step is still in progress, not done, so the heart must not read full.
    testWidgets(
      'passes the calibrated height for the fraction, not the raw one',
      (tester) async {
        for (final step in [1, 2, 3, 4, 5]) {
          await pumpHarness(
            tester,
            OnboardingProgress(step: step, totalSteps: 5),
          );
          final rawFraction = (step - 1) / 5;
          expect(
            painterFor(tester).revealHeight,
            HeartFillGeometry.heightFractionForArea(rawFraction),
            reason:
                'step $step must be wired through HeartFillGeometry, not '
                'passed straight through as revealHeight',
          );
        }
      },
    );

    testWidgets('reads visibly less than full at the last step', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        const OnboardingProgress(step: 5, totalSteps: 5),
      );

      // Step 5 is still in progress (not yet submitted), so the heart must
      // not read as done — this is the exact user-facing complaint that
      // both the height-crop and the opacity-fade attempts failed on.
      expect(painterFor(tester).revealHeight, lessThan(1.0));
    });

    testWidgets('fills in red, not the alarm red used for errors', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        const OnboardingProgress(step: 3, totalSteps: 5),
      );

      final fillColor = painterFor(tester).fillColor;
      expect(fillColor, WishtickColors.light.heartFill);
      expect(
        fillColor,
        isNot(WishtickColors.light.danger),
        reason: 'progress must not borrow the alarm colour',
      );
    });
  });
}
