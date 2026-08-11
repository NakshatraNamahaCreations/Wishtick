import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/app.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/core/theme/app_palette.dart';
import 'package:wishtick_flutter/core/theme/theme_controller.dart';
import 'package:wishtick_flutter/features/auth/data/auth_repository.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/load_app_fonts.dart';
import '../../helpers/onboarding_fakes.dart';

/// Pumps the real app with [themeMode] persisted, then advances [advance].
///
/// The default lands early in the splash. Pass [Duration.zero] to inspect the
/// first frame, or ~3.5s to see the entrance settled but before the 4s
/// `AppDurations.splash` elapses and the router redirects away.
Future<void> _pumpSplash(
  WidgetTester tester,
  String themeMode, {
  Duration advance = const Duration(milliseconds: 300),
}) async {
  SharedPreferences.setMockInitialValues({
    ThemeModeController.prefsKey: themeMode,
  });
  final prefs = await SharedPreferences.getInstance();

  tester.view
    ..physicalSize = const Size(393, 852)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        onboardingRepositoryProvider.overrideWithValue(
          FakeOnboardingRepository(),
        ),
      ],
      child: const WishtickApp(),
    ),
  );
  await tester.pump(advance);
}

/// Chooses which of the two code paths the splash takes.
///
/// Widget tests run with `MediaQuery.disableAnimations` **true** by default, so
/// the reduce-motion branch — mark square and text opaque from frame one — is
/// what a test gets unless it says otherwise. Every test in the entrance group
/// therefore states its choice rather than inheriting the ambient default:
/// relying on it made the reduce-motion case pass alone and fail in the group.
void _setAnimations(WidgetTester tester, {required bool enabled}) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: !enabled);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Cosine of the mark's Y rotation: 1.0 face-on, −1.0 fully turned away.
double _markFacing(WidgetTester tester) {
  final transform = tester
      .widget<Transform>(
        find
            .ancestor(of: find.byType(Image), matching: find.byType(Transform))
            .first,
      )
      .transform;
  return transform.getRow(0)[0];
}

/// Opacity currently applied to [text] by its entrance transition.
double _textOpacity(WidgetTester tester, String text) {
  return tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;
}

/// The single gradient-bearing box on the splash — its backdrop.
Gradient _backdrop(WidgetTester tester) {
  final gradients = tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((d) => d.decoration)
      .whereType<BoxDecoration>()
      .map((d) => d.gradient)
      .nonNulls
      .toList();
  expect(gradients, hasLength(1), reason: 'expected exactly one backdrop');
  return gradients.single;
}

/// Regression test for the left-hugging splash (found on a real device).
///
/// A Scaffold body gets *loose* width constraints; with every splash child
/// being intrinsic-width, the Column shrank to its widest text and sat at the
/// left edge. The default test font hid this — it draws every glyph as a
/// full-em square, which made the caption span nearly the whole view and
/// accidentally centre everything. So this test loads the *bundled* fonts and
/// asserts real glyph geometry.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  testWidgets('splash content is horizontally centred with real fonts', (
    tester,
  ) async {
    await _pumpSplash(tester, 'light');

    // With Montserrat loaded this text is ~200px wide — far narrower than the
    // 393px view — so only a genuinely full-width Column centres it.
    for (final text in [
      'Wishtick',
      'Gifting, made together',
      'Setting up your celebrations',
    ]) {
      final rect = tester.getRect(find.text(text));
      expect(rect.width, lessThan(320), reason: '"$text" should be intrinsic');
      expect(
        rect.center.dx,
        moreOrLessEquals(393 / 2, epsilon: 1),
        reason: '"$text" is off-centre',
      );
    }
  });

  // The entrance rides the same controller as the progress bar, so it must be
  // fully settled before AppDurations.splash elapses and the router redirects
  // — otherwise the last thing the user sees is a half-finished animation.
  group('entrance animation', () {
    const texts = ['Wishtick', 'Gifting, made together'];

    testWidgets('starts turned away and transparent', (tester) async {
      _setAnimations(tester, enabled: true);
      await _pumpSplash(tester, 'light', advance: Duration.zero);

      expect(
        _markFacing(tester),
        moreOrLessEquals(-1, epsilon: 0.01),
        reason: 'the mark should open back-facing, mid-flip',
      );
      for (final text in texts) {
        expect(
          _textOpacity(tester, text),
          0,
          reason: '"$text" should be hidden',
        );
      }
    });

    testWidgets('settles square and opaque before the redirect', (
      tester,
    ) async {
      _setAnimations(tester, enabled: true);
      // 3.5s — past the last stage (ends at 2.9s) but short of the 4s
      // completion that fires the session restore and routes away.
      await _pumpSplash(
        tester,
        'light',
        advance: const Duration(milliseconds: 3500),
      );

      expect(
        _markFacing(tester),
        moreOrLessEquals(1, epsilon: 0.01),
        reason: 'the mark should land face-on',
      );
      for (final text in texts) {
        expect(
          _textOpacity(tester, text),
          1,
          reason: '"$text" should be shown',
        );
      }
    });

    testWidgets('is staggered — the mark leads the wordmark', (tester) async {
      _setAnimations(tester, enabled: true);
      // Stage windows over the 4s timeline: mark 0–900ms, wordmark
      // 900–2500ms, tagline 1300–2900ms. At 1.8s the three are in three
      // different states — mark landed, wordmark part-way, tagline not yet
      // begun. Sampled here rather than at 2s, where the wordmark reaches
      // 0.999 and the assertion would hold by a thousandth.
      await _pumpSplash(
        tester,
        'light',
        advance: const Duration(milliseconds: 1800),
      );

      expect(_markFacing(tester), greaterThan(0.99), reason: 'mark landed');

      final wordmark = _textOpacity(tester, 'Wishtick');
      expect(wordmark, greaterThan(0), reason: 'the wordmark has begun');
      expect(wordmark, lessThan(1), reason: 'the wordmark is not yet finished');
      expect(
        _textOpacity(tester, 'Gifting, made together'),
        lessThan(wordmark),
        reason: 'the tagline trails the wordmark',
      );
    });

    // A logo spinning in 3D is exactly what "reduce motion" exists to stop.
    // Note this is the *default* in widget tests — see [_enableAnimations].
    testWidgets('is skipped entirely under reduce motion', (tester) async {
      _setAnimations(tester, enabled: false);
      await _pumpSplash(tester, 'light', advance: Duration.zero);

      // The mark is drawn with no Transform wrapping it at all — the flip
      // widget passes its child straight through.
      expect(
        find.ancestor(of: find.byType(Image), matching: find.byType(Transform)),
        findsNothing,
      );
      // Text is asserted by effective opacity rather than by the absence of a
      // FadeTransition: the router wraps every page in transitions of its own,
      // so "no FadeTransition anywhere above this Text" is never true. What
      // matters is that the brand is legible on the very first frame.
      for (final text in texts) {
        expect(find.text(text), findsOneWidget);
        expect(
          _textOpacity(tester, text),
          1,
          reason: '"$text" should be visible immediately',
        );
      }
    });
  });

  // The splash is a brand moment, not a page: it must look identical whichever
  // theme is active. Nothing else in the app is exempt from theming, so the
  // exemption is pinned here rather than left to a code comment.
  group('backdrop is theme-invariant', () {
    const stops = [AppPalette.plumMuted, AppPalette.plumNight];

    for (final mode in ['light', 'dark']) {
      testWidgets('$mode mode paints the plum wash', (tester) async {
        await _pumpSplash(tester, mode);

        final gradient = _backdrop(tester);
        expect(gradient, isA<LinearGradient>());
        expect(gradient.colors, stops);
        expect(
          (gradient as LinearGradient).begin,
          Alignment.topCenter,
          reason: 'the wash falls top-to-bottom',
        );
      });

      testWidgets('$mode mode draws every foreground on-dark', (tester) async {
        await _pumpSplash(tester, mode);

        // colours.primary and textSecondary would render plum-on-plum and
        // near-invisible grey here under the light theme.
        for (final text in [
          'Wishtick',
          'Gifting, made together',
          'Setting up your celebrations',
        ]) {
          expect(
            tester.widget<Text>(find.text(text)).style?.color,
            AppPalette.ivory,
            reason: '"$text" must use the on-dark ink',
          );
        }
      });
    }
  });
}
