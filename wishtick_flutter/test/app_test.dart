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
import 'package:wishtick_flutter/features/splash/presentation/splash_screen.dart';

import 'helpers/auth_fakes.dart';

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
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final instance = await SharedPreferences.getInstance();
    final auth = FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(instance),
          tokenStorageProvider.overrideWithValue(
            FakeTokenStorage(refreshToken: signedIn ? 'refresh' : null),
          ),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: const WishtickApp(),
      ),
    );
    return auth;
  }

  /// Runs the splash animation out and lets the redirect settle.
  Future<void> passSplash(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  group('startup', () {
    testWidgets('opens on the splash screen', (tester) async {
      await pumpApp(tester);

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Wishtick'), findsOneWidget);
      expect(find.text('Gifting, made together'), findsOneWidget);
      expect(find.text('Setting up your celebrations'), findsOneWidget);
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
      expect(find.text('Continue'), findsOneWidget);
      // No stored session, so the server is never asked who we are.
      expect(auth.meCalls, 0);
    });

    testWidgets('sends a signed-in user straight to the tab shell', (
      tester,
    ) async {
      final auth = await pumpApp(tester, signedIn: true);
      await passSplash(tester);

      expect(auth.meCalls, 1);
      expect(find.byType(WishtickBottomNav), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
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
      expect(find.text('Lands in Sprint 4 — Home & discovery'), findsOneWidget);
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

      expect(find.text('Lands in Sprint 8 — Memories'), findsOneWidget);
    });
  });

  group('theme', () {
    testWidgets('applies the persisted dark theme on launch', (tester) async {
      await pumpApp(tester, prefs: {ThemeModeController.prefsKey: 'dark'});

      final context = tester.element(find.byType(SplashScreen));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(
        Theme.of(context).extension<WishtickColors>()!.background,
        WishtickColors.dark.background,
      );
    });

    testWidgets('applies the persisted light theme on launch', (tester) async {
      await pumpApp(tester, prefs: {ThemeModeController.prefsKey: 'light'});

      final context = tester.element(find.byType(SplashScreen));
      expect(Theme.of(context).brightness, Brightness.light);
    });
  });
}
