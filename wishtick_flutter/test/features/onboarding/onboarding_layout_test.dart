import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/app.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/core/theme/app_dimens.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/theme/theme_controller.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_swipe_button.dart';
import 'package:wishtick_flutter/features/auth/data/auth_repository.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/onboarding/domain/profile_draft.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/avatar_picker_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/load_app_fonts.dart';
import '../../helpers/onboarding_fakes.dart';

/// Geometry regression tests for onboarding — Figma `31:608` and `195:131`.
///
/// These exist because a *loose* width constraint let hand-rolled widgets
/// shrink to their content: the Continue pill collapsed to a narrow badge with
/// the gold check sitting on top of the label ("✓nue"), and the gender tiles
/// hugged the left of their slots. The whole class was invisible to the suite
/// because the default test font inflates text width — see [loadAppFonts].
///
/// So: real fonts, a fixed 393x852 view, and assertions on actual rects.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  const viewWidth = 393.0;
  const contentWidth = viewWidth - 2 * AppSpacing.screenGutter;

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      ThemeModeController.prefsKey: 'light',
    });
    final prefs = await SharedPreferences.getInstance();

    tester.view
      ..physicalSize = const Size(viewWidth, 852)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStorageProvider.overrideWithValue(
            FakeTokenStorage(refreshToken: 'refresh'),
          ),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          onboardingRepositoryProvider.overrideWithValue(
            FakeOnboardingRepository(),
          ),
        ],
        child: const WishtickApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  // The screens below happen to hand the button a tight width, so they would
  // stay green even if the widget itself were fragile. This asserts the
  // widget's own contract: full-bleed no matter what the caller supplies.
  testWidgets('the primary button fills its width under loose constraints', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(viewWidth, 852)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          // A Column with the default centre alignment — the exact shape that
          // collapsed the pill into a narrow badge on device.
          body: Column(
            children: [WishtickSwipeButton(onSwiped: () async => true)],
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byType(WishtickSwipeButton));
    expect(
      rect.width,
      moreOrLessEquals(viewWidth, epsilon: 1),
      reason: 'the pill collapsed to its content',
    );
  });

  group('Create Profile', () {
    testWidgets('the Continue pill spans the full content width', (
      tester,
    ) async {
      await pump(tester);

      final pill = tester.getRect(find.byType(WishtickSwipeButton));
      expect(pill.width, moreOrLessEquals(contentWidth, epsilon: 1));
      expect(pill.height, moreOrLessEquals(AppSizes.buttonHeight, epsilon: 1));
      expect(pill.center.dx, moreOrLessEquals(viewWidth / 2, epsilon: 1));
    });

    testWidgets('the gold arrow badge does not overlap the label', (
      tester,
    ) async {
      await pump(tester);

      final badge = tester.getRect(
        find.descendant(
          of: find.byType(WishtickSwipeButton),
          matching: find.byIcon(Icons.chevron_right),
        ),
      );
      final label = tester.getRect(
        find.descendant(
          of: find.byType(WishtickSwipeButton),
          matching: find.text('Swipe to continue'),
        ),
      );

      // The exact symptom that was reported: the badge sat on top of the text.
      expect(
        badge.right,
        lessThan(label.left),
        reason: 'the check badge is overlapping the label',
      );
      // And the label stays optically centred on the pill, not pushed across.
      expect(label.center.dx, moreOrLessEquals(viewWidth / 2, epsilon: 2));
    });

    testWidgets('the three gender tiles are equal and span the content', (
      tester,
    ) async {
      await pump(tester);

      final rects = [
        for (final gender in Gender.values)
          tester.getRect(find.text(gender.label)),
      ];
      // Each label sits in its own third of the row, in order.
      expect(rects[0].center.dx, lessThan(rects[1].center.dx));
      expect(rects[1].center.dx, lessThan(rects[2].center.dx));

      // The tiles themselves — the nearest Container ancestor of each label.
      final tileRects = <Rect>[
        for (final gender in Gender.values)
          tester.getRect(
            find
                .ancestor(
                  of: find.text(gender.label),
                  matching: find.byType(Container),
                )
                .first,
          ),
      ];

      final width = tileRects.first.width;
      for (final rect in tileRects) {
        expect(
          rect.width,
          moreOrLessEquals(width, epsilon: 1),
          reason: 'gender tiles must be equal width',
        );
      }
      // Three tiles plus two gaps fill the content column.
      expect(
        tileRects.last.right - tileRects.first.left,
        moreOrLessEquals(contentWidth, epsilon: 1),
      );
      expect(
        width,
        greaterThan(80),
        reason: 'a tile shrunk to its content instead of filling its slot',
      );
    });
  });

  group('Avatar picker', () {
    Future<void> openPicker(WidgetTester tester) async {
      await pump(tester);
      await tester.tap(find.text('Select Avatar'));
      await tester.pumpAndSettle();
      expect(find.byType(AvatarPickerScreen), findsOneWidget);
    }

    testWidgets('the Continue pill spans the full content width', (
      tester,
    ) async {
      await openPicker(tester);

      final pill = tester.getRect(find.byType(WishtickSwipeButton));
      expect(pill.width, moreOrLessEquals(contentWidth, epsilon: 1));
      expect(pill.center.dx, moreOrLessEquals(viewWidth / 2, epsilon: 1));
    });

    testWidgets('the avatar grid is four columns of equal circles', (
      tester,
    ) async {
      await openPicker(tester);

      Rect tileOf(int index) => tester.getRect(
        find
            .byWidgetPredicate(
              (w) =>
                  w is Image &&
                  w.image is AssetImage &&
                  (w.image as AssetImage).assetName ==
                      BundledAvatar(index).asset,
            )
            .first,
      );

      final first = tileOf(1);
      final second = tileOf(2);
      final fifth = tileOf(5);

      expect(first.width, moreOrLessEquals(first.height, epsilon: 1));
      expect(second.width, moreOrLessEquals(first.width, epsilon: 1));
      // Rows sit twice as far apart as columns, per the export.
      expect(
        second.left - first.left,
        moreOrLessEquals(first.width + AppSpacing.xl, epsilon: 1),
      );
      expect(
        fifth.top - first.top,
        moreOrLessEquals(first.height + AppSpacing.huge, epsilon: 1),
      );
    });

    testWidgets('selecting an avatar does not resize it', (tester) async {
      await openPicker(tester);

      Finder image(int index) => find
          .byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName == BundledAvatar(index).asset,
          )
          .first;

      final before = tester.getRect(image(3));
      await tester.tap(image(3));
      await tester.pumpAndSettle();
      final after = tester.getRect(image(3));

      // The ring used to be a Border on the container, which insets its child
      // — so choosing an avatar shrank it and the grid visibly jittered.
      expect(after, before);
    });
  });
}
