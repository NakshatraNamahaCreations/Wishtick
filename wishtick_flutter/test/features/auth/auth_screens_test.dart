import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/app.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/theme/theme_controller.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_bottom_nav.dart';
import 'package:wishtick_flutter/features/auth/data/auth_repository.dart';
import 'package:wishtick_flutter/features/auth/presentation/mobile_number_screen.dart';
import 'package:wishtick_flutter/features/auth/presentation/otp_screen.dart';
import 'package:wishtick_flutter/features/auth/presentation/welcome_screen.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/create_profile_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/onboarding_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FakeAuthRepository> pumpApp(
    WidgetTester tester, {
    String themeMode = 'light',
    bool onboarded = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      ThemeModeController.prefsKey: themeMode,
    });
    final prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthRepository();

    tester.view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          authRepositoryProvider.overrideWithValue(auth),
          onboardingRepositoryProvider.overrideWithValue(
            FakeOnboardingRepository(completed: onboarded),
          ),
        ],
        child: const WishtickApp(),
      ),
    );
    // Past the splash and onto the welcome carousel.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    return auth;
  }

  /// Walks the carousel to the last slide and taps through to sign-in.
  Future<void> reachMobileScreen(WidgetTester tester) async {
    for (var i = 0; i < WelcomeScreen.slides.length - 1; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
  }

  Future<void> enterNumber(WidgetTester tester, String number) async {
    await tester.enterText(find.byType(TextField).first, number);
    await tester.pumpAndSettle();
  }

  /// Ticks the required Terms box — the first of the two consent checkboxes.
  ///
  /// GET OTP stays disabled without it, so every test that submits the form
  /// has to do what a user does.
  Future<void> acceptTerms(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
  }

  group('welcome carousel', () {
    testWidgets('opens on the first slide from the design', (tester) async {
      await pumpApp(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Make Every\nWish Count!'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('advances through all four slides', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Every Ocassion\nMade Special!'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Great Gifts\nBring Us Together!'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('The Little Moments\nMatter Most !'), findsOneWidget);

      // The final slide's button changes label.
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('leads into the sign-in screen', (tester) async {
      await pumpApp(tester);
      await reachMobileScreen(tester);

      expect(find.byType(MobileNumberScreen), findsOneWidget);
      expect(find.text('Ready to Celebrate?'), findsOneWidget);
    });
  });

  group('mobile number screen', () {
    testWidgets('keeps GET OTP disabled until the number is complete', (
      tester,
    ) async {
      final auth = await pumpApp(tester);
      await reachMobileScreen(tester);

      final button = find.widgetWithText(ElevatedButton, 'GET OTP');
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

      await enterNumber(tester, '98765');
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

      // A complete number is no longer enough on its own.
      await enterNumber(tester, '9876543210');
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

      await acceptTerms(tester);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
      expect(auth.requestedSignInFor, isEmpty);
    });

    testWidgets('shows both consent rows, neither pre-ticked', (tester) async {
      await pumpApp(tester);
      await reachMobileScreen(tester);

      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(
        find.textContaining('I agree to the', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text(
          "I'd like to receive promotional emails and offers (Optional)",
        ),
        findsOneWidget,
      );

      // A pre-ticked consent box is not consent — both start empty.
      for (final box in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
        expect(box.value, isFalse);
      }
    });

    testWidgets('tapping the label toggles its box', (tester) async {
      await pumpApp(tester);
      await reachMobileScreen(tester);

      await tester.tap(
        find.text(
          "I'd like to receive promotional emails and offers (Optional)",
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widgetList<Checkbox>(find.byType(Checkbox)).last.value,
        isTrue,
      );
    });

    testWidgets('the optional opt-in does not gate the button', (tester) async {
      await pumpApp(tester);
      await reachMobileScreen(tester);
      await enterNumber(tester, '9876543210');

      final button = find.widgetWithText(ElevatedButton, 'GET OTP');

      // Ticking only the promotional box leaves the form incomplete: it is the
      // Terms box that unlocks it, and the two must not be conflated.
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

      await acceptTerms(tester);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    });

    testWidgets('requests a code and opens the OTP screen', (tester) async {
      final auth = await pumpApp(tester);
      await reachMobileScreen(tester);
      await enterNumber(tester, '9876543210');
      await acceptTerms(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'GET OTP'));
      await tester.pumpAndSettle();

      expect(auth.requestedSignInFor, ['+919876543210']);
      expect(find.byType(OtpScreen), findsOneWidget);
      expect(find.text('Enter OTP'), findsOneWidget);
    });

    testWidgets('shows a failure without leaving the screen', (tester) async {
      final auth = await pumpApp(tester);
      auth.requestCodeFailure = const ApiException(
        code: ApiException.codeNetwork,
        message: 'No internet connection.',
      );
      await reachMobileScreen(tester);
      await enterNumber(tester, '9876543210');
      await acceptTerms(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'GET OTP'));
      await tester.pumpAndSettle();

      expect(find.byType(OtpScreen), findsNothing);
      expect(
        find.text('No connection. Check your network and retry.'),
        findsOneWidget,
      );
    });
  });

  group('OTP screen', () {
    Future<FakeAuthRepository> reachOtp(WidgetTester tester) async {
      final auth = await pumpApp(tester);
      await reachMobileScreen(tester);
      await enterNumber(tester, '9876543210');
      await acceptTerms(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'GET OTP'));
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('renders one box per digit of the backend code length', (
      tester,
    ) async {
      await reachOtp(tester);

      // Six, matching OTP_LENGTH and the screen's own "6-digit code" copy.
      expect(find.text('We sent a 6-digit code to your phone'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxWidth == 48,
        ),
        findsNWidgets(AuthRepository.otpLength),
      );
    });

    testWidgets('shows the number and a resend countdown', (tester) async {
      await reachOtp(tester);

      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('edit'), findsOneWidget);
      expect(find.textContaining('Resend code in'), findsOneWidget);
    });

    testWidgets('verifies automatically once six digits are entered', (
      tester,
    ) async {
      final auth = await reachOtp(tester);

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pumpAndSettle();

      expect(auth.verifiedSignIns.single.code, '123456');
      // A returning, onboarded user lands straight on the tab shell.
      expect(find.byType(WishtickBottomNav), findsOneWidget);
    });

    testWidgets('a brand-new account goes to onboarding, not the shell', (
      tester,
    ) async {
      final auth = await reachOtp(tester);
      auth.nextIsNewUser = true;

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pumpAndSettle();

      expect(find.byType(CreateProfileScreen), findsOneWidget);
      expect(find.byType(WishtickBottomNav), findsNothing);
    });

    testWidgets('reports a wrong code and clears the boxes', (tester) async {
      final auth = await reachOtp(tester);
      auth.verifyCodeFailure = const ApiException(
        code: 'OTP_INVALID',
        message: 'Incorrect code',
        statusCode: 400,
        details: {'attemptsRemaining': 4},
      );

      await tester.enterText(find.byType(TextField).first, '000000');
      await tester.pumpAndSettle();

      expect(find.text('That code is incorrect.'), findsOneWidget);
      expect(find.text('4 attempts remaining'), findsOneWidget);
      expect(find.byType(OtpScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        isEmpty,
      );
    });

    testWidgets('edit returns to the number screen', (tester) async {
      await reachOtp(tester);

      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();

      expect(find.byType(MobileNumberScreen), findsOneWidget);
      // The number is retained so it can be corrected rather than retyped.
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        '9876543210',
      );
    });
  });

  group('dark palette', () {
    // Built straight on AppTheme.dark rather than through a stored preference:
    // the app is light-only for now (kDarkModeEnabled), so a 'dark' pref no
    // longer changes anything. The palette is still live and still has to lay
    // out.
    testWidgets('renders the mobile screen without overflow', (tester) async {
      SharedPreferences.setMockInitialValues({});
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
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const MobileNumberScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enterNumber(tester, '9876543210');
      await acceptTerms(tester);

      final context = tester.element(find.byType(MobileNumberScreen));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    });
  });
}
