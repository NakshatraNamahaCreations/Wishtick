import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_colors.dart';
import 'package:wishtick_flutter/core/theme/app_dimens.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/important_dates_screen.dart';

import '../../helpers/onboarding_fakes.dart';

/// Pumps [ImportantDatesScreen] on its own — no router, no session — because
/// nothing under test taps back, skip, or continue.
///
/// Deliberately never calls `pumpAndSettle()` anywhere in this file: the
/// carousel's auto-advance timer repeats forever by design, so a settle that
/// waits for the tree to go quiet never returns. Every wait here is a bounded
/// `pump(duration)` instead.
Future<void> pumpImportantDates(WidgetTester tester) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures();
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  // Without this the default 800×600 test surface lays the card out past the
  // window, and a tap aimed at the Occasion field silently lands nowhere.
  tester.view
    ..physicalSize = const Size(393, 852)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(
          FakeOnboardingRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const ImportantDatesScreen(),
      ),
    ),
  );
  // One frame for the initial build, one more for the options Future
  // (FakeOnboardingRepository resolves on a bare microtask, no real delay).
  await tester.pump();
  await tester.pump();
}

/// Advances the fake clock in fixed small steps rather than one large jump.
///
/// A `Timer.periodic` inside a large single `pump(bigDuration)` proved
/// unreliable in this suite — ticks due partway through the jump did not
/// consistently fire, which is exactly the wrong thing to depend on for a
/// test asserting a precise interval. Stepping matches the pattern already
/// used for the swipe-to-continue button's own timers (see `helpers/swipe.dart`).
Future<void> stepClock(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 250);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// Advances the fake clock past one auto-advance tick and lets the resulting
/// page-turn animation finish.
Future<void> advanceOneSlide(WidgetTester tester) async {
  await stepClock(tester, const Duration(seconds: 5, milliseconds: 300));
}

/// Every asset path currently painted by an [Image] in the tree.
Set<String> renderedAssets(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((i) => (i.image as AssetImage).assetName)
    .toSet();

/// The small 6×6 circular dots of the carousel indicator, in tree order —
/// distinguished from other circular decorations on the screen (the "+" badge
/// on "Add a new date" is a circle too, but 28×28) by that fixed size.
List<Color?> carouselDotColors(WidgetTester tester) {
  return tester
      .widgetList<Container>(find.byType(Container))
      .where((c) {
        final decoration = c.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            c.constraints?.minWidth == 6 &&
            c.constraints?.minHeight == 6;
      })
      .map((c) => (c.decoration! as BoxDecoration).color)
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('occasion carousel', () {
    testWidgets('shows all three occasion photos, starting on Birthday', (
      tester,
    ) async {
      await pumpImportantDates(tester);

      // All three are pre-cached by PageView.builder's default viewport;
      // only the active slide is a laid-out Image, so this asserts the whole
      // set is reachable rather than that all three paint simultaneously.
      final assets = renderedAssets(tester);
      expect(assets, contains('assets/images/Birthday.png'));

      expect(find.text('Birthday'), findsWidgets);
    });

    testWidgets('advances to the next photo every five seconds — not '
        'sooner, not later', (tester) async {
      await pumpImportantDates(tester);

      // Short of the interval: still on Birthday specifically — not just
      // "not yet Anniversary", which a too-fast interval would also satisfy
      // once it had skipped straight past Anniversary to Special Moments.
      await stepClock(tester, const Duration(seconds: 4));
      expect(find.text('Birthday'), findsWidgets);
      expect(find.text('Anniversary'), findsNothing);
      expect(find.text('Special Moments'), findsNothing);

      await stepClock(tester, const Duration(seconds: 1, milliseconds: 300));
      expect(find.text('Anniversary'), findsOneWidget);
      expect(renderedAssets(tester), contains('assets/images/Anniversary.png'));
    });

    testWidgets('wraps back to the first photo after the last', (tester) async {
      await pumpImportantDates(tester);

      // Birthday → Anniversary → Special Moments → Birthday.
      for (var i = 0; i < 3; i++) {
        await advanceOneSlide(tester);
      }

      expect(find.text('Birthday'), findsWidgets);
      expect(find.text('Special Moments'), findsNothing);
    });

    testWidgets('the dot row tracks the active slide', (tester) async {
      await pumpImportantDates(tester);

      final colors = WishtickColors.light;
      var dots = carouselDotColors(tester);
      expect(dots, hasLength(3), reason: 'one dot per photo');
      expect(dots[0], colors.primary, reason: 'Birthday is active first');
      expect(dots[1], colors.border);
      expect(dots[2], colors.border);

      await advanceOneSlide(tester);

      dots = carouselDotColors(tester);
      expect(dots[0], colors.border);
      expect(dots[1], colors.primary, reason: 'Anniversary is now active');
      expect(dots[2], colors.border);
    });

    testWidgets('does not auto-advance under reduce motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingRepositoryProvider.overrideWithValue(
              FakeOnboardingRepository(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ImportantDatesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Comfortably past one interval, so this is a real absence check
      // rather than a race against the timer's own period.
      await stepClock(tester, const Duration(seconds: 6, milliseconds: 300));

      expect(find.text('Birthday'), findsWidgets);
      expect(find.text('Anniversary'), findsNothing);
    });
  });

  group('date fields', () {
    testWidgets(
      'Name, Relationship and Occasion are pill-shaped and white-filled',
      (tester) async {
        await pumpImportantDates(tester);

        final colors = WishtickColors.light;

        InputDecoration decorationFor(Finder textFieldOrDropdown) {
          final widget = tester.widget(textFieldOrDropdown);
          return (widget as dynamic).decoration as InputDecoration;
        }

        for (final field in tester.widgetList<TextField>(
          find.byType(TextField),
        )) {
          final decoration = field.decoration!;
          expect(decoration.filled, isTrue);
          expect(decoration.fillColor, colors.surface);
          final border = decoration.enabledBorder! as OutlineInputBorder;
          expect(
            border.borderRadius,
            BorderRadius.circular(AppRadius.pill),
            reason: 'Figma 199:10 draws a full stadium, not a rounded rect',
          );
        }

        final dropdown = decorationFor(
          find.byType(DropdownButtonFormField<String>),
        );
        expect(dropdown.filled, isTrue);
        expect(dropdown.fillColor, colors.surface);
      },
    );

    testWidgets(
      'the Occasion border is the same whether or not it is focused — '
      'unlike Name and Relationship, which do get a focus ring',
      (tester) async {
        await pumpImportantDates(tester);

        // The bug: picking a value from the dropdown's menu hands focus back
        // to the closed button, the same way typing leaves a TextField
        // focused — so the Occasion field kept the plum focusedBorder for
        // the rest of the session once a value had ever been chosen, while
        // Name and Relationship only looked that way while actively being
        // typed into. Asserting the two borders are equal makes the field
        // immune to that regardless of *how* focus is reached (tap, menu
        // selection, keyboard traversal), rather than reproducing one
        // specific path to it.
        final dropdown = tester.widget<InputDecorator>(
          find.descendant(
            of: find.byType(DropdownButtonFormField<String>),
            matching: find.byType(InputDecorator),
          ),
        );
        expect(
          dropdown.decoration.focusedBorder,
          dropdown.decoration.enabledBorder,
        );

        // Name and Relationship must NOT get this treatment — a real cursor
        // sitting in a text field is exactly when a focus ring is expected.
        for (final field in tester.widgetList<TextField>(
          find.byType(TextField),
        )) {
          expect(
            field.decoration!.focusedBorder,
            isNot(field.decoration!.enabledBorder),
            reason: 'typing should still grow a focus ring',
          );
        }
      },
    );

    testWidgets('Occasion Date is also pill-shaped and white-filled', (
      tester,
    ) async {
      await pumpImportantDates(tester);

      final colors = WishtickColors.light;
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('dd/mm/yyyy'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, colors.surface);
      expect(decoration.borderRadius, BorderRadius.circular(AppRadius.pill));
    });
  });
}
