import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/app.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/core/theme/app_colors.dart';
import 'package:wishtick_flutter/core/theme/theme_controller.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_bottom_nav.dart';
import 'package:wishtick_flutter/features/auth/data/auth_repository.dart';
import 'package:wishtick_flutter/features/auth/presentation/welcome_screen.dart';
import 'package:wishtick_flutter/features/home/data/home_repository.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/create_profile_screen.dart';
import 'package:wishtick_flutter/features/splash/presentation/splash_screen.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';

import 'helpers/auth_fakes.dart';
import 'helpers/home_fakes.dart';
import 'helpers/onboarding_fakes.dart';
import 'helpers/wishlist_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps the real app with a scripted session.
  ///
  /// [signedIn] decides whether a refresh token is present, which is what the
  /// splash checks before the router redirects.
  Future<FakeAuthRepository> pumpApp(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool signedIn = false,
    bool onboarded = true,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final instance = await SharedPreferences.getInstance();
    final auth = FakeAuthRepository();

    // A phone-sized surface: the default 800x600 test window is shorter than
    // any real device and makes phone layouts look broken.
    tester.view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(instance),
          tokenStorageProvider.overrideWithValue(
            FakeTokenStorage(refreshToken: signedIn ? 'refresh' : null),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          // Without this the session's onboarding check reaches for the real
          // network and every test waits out the connect timeout.
          onboardingRepositoryProvider.overrideWithValue(
            FakeOnboardingRepository(completed: onboarded),
          ),
          // Home reads four rails on first frame; without fakes each one
          // reaches the real network and the test waits out a connect timeout.
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
          wishlistRepositoryProvider.overrideWithValue(
            FakeWishlistRepository(),
          ),
        ],
        child: const WishtickApp(),
      ),
    );
    return auth;
  }

  /// Runs the splash's hold-time out and lets the redirect settle.
  Future<void> passSplash(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  group('startup', () {
    testWidgets('opens on the splash screen', (tester) async {
      await pumpApp(tester);

      expect(find.byType(SplashScreen), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, SplashScreen.asset);
    });

    testWidgets('stays on the splash until the session resolves', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('sends a signed-out user to the welcome flow', (tester) async {
      final auth = await pumpApp(tester, signedIn: false);
      await passSplash(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      // The carousel's copy and its button are drawn into the artwork, so the
      // slide's own name is what proves the first one is up.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == WelcomeScreen.slides.first.action,
        ),
        findsOneWidget,
      );
      // No stored session, so the server is never asked who we are.
      expect(auth.meCalls, 0);
    });

    testWidgets('sends a signed-in, onboarded user to the tab shell', (
      tester,
    ) async {
      final auth = await pumpApp(tester, signedIn: true);
      await passSplash(tester);

      expect(auth.meCalls, 1);
      expect(find.byType(WishtickBottomNav), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('holds a signed-in user in onboarding until it is finished', (
      tester,
    ) async {
      await pumpApp(tester, signedIn: true, onboarded: false);
      await passSplash(tester);

      expect(find.byType(CreateProfileScreen), findsOneWidget);
      expect(find.byType(WishtickBottomNav), findsNothing);
    });

    testWidgets('onboarding is unreachable once it is complete', (
      tester,
    ) async {
      await pumpApp(tester, signedIn: true);
      await passSplash(tester);

      expect(find.byType(CreateProfileScreen), findsNothing);
      expect(find.byType(WishtickBottomNav), findsOneWidget);
    });
  });

  group('tab shell', () {
    testWidgets('shows every destination', (tester) async {
      await pumpApp(tester, signedIn: true);
      await passSplash(tester);

      for (final item in WishtickBottomNav.items) {
        expect(
          find.descendant(
            of: find.byType(WishtickBottomNav),
            matching: find.text(item.label),
          ),
          findsOneWidget,
          reason: '${item.label} tab is missing',
        );
      }
      // Home is a real screen now; its delivery header is the stable marker.
      expect(find.text('Where To Deliver?'), findsOneWidget);
    });

    testWidgets('switches tabs through the bottom navigation', (tester) async {
      await pumpApp(tester, signedIn: true);
      await passSplash(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(WishtickBottomNav),
          matching: find.text('Memories'),
        ),
      );
      await tester.pumpAndSettle();

      // The Memories tab is real as of Sprint 8; its hero is what proves the
      // branch switched.
      expect(find.text('Every wish locked with Love'), findsOneWidget);
    });
  });

  group('theme', () {
    testWidgets('stays light even with a dark preference on disk', (
      tester,
    ) async {
      // The app is light-only for now (kDarkModeEnabled). A preference left by
      // an older build — or a device set to dark — must not flip it.
      await pumpApp(tester, prefs: {ThemeModeController.prefsKey: 'dark'});

      final context = tester.element(find.byType(SplashScreen));
      expect(Theme.of(context).brightness, Brightness.light);
      expect(
        Theme.of(context).extension<WishtickColors>()!.background,
        WishtickColors.light.background,
      );
    });

    testWidgets('applies the persisted light theme on launch', (tester) async {
      await pumpApp(tester, prefs: {ThemeModeController.prefsKey: 'light'});

      final context = tester.element(find.byType(SplashScreen));
      expect(Theme.of(context).brightness, Brightness.light);
    });

    testWidgets('offers no dark theme at all while it is off', (tester) async {
      // Withholding `darkTheme` is what stops the platform brightness from
      // choosing for us; pinning themeMode alone would not.
      await pumpApp(tester);

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
      expect(app.darkTheme, isNull);
      expect(app.themeMode, ThemeMode.light);
    });
  });
}
