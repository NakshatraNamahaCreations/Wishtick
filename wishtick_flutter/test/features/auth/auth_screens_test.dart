import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/app.dart';
import 'package:wishtick_flutter/core/legal/legal_document_screen.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/core/theme/app_colors.dart';
import 'package:wishtick_flutter/core/theme/app_dimens.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/theme/theme_controller.dart';
import 'package:wishtick_flutter/core/widgets/circle_back_button.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_bottom_nav.dart';
import 'package:wishtick_flutter/features/auth/data/auth_repository.dart';
import 'package:wishtick_flutter/features/auth/presentation/mobile_number_screen.dart';
import 'package:wishtick_flutter/features/auth/presentation/otp_screen.dart';
import 'package:wishtick_flutter/features/auth/presentation/welcome_screen.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/create_profile_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/load_app_fonts.dart';
import '../../helpers/onboarding_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Real geometry, not Ahem's full-em squares — required for the gap
  // assertion below to mean anything (see loadAppFonts' own doc comment).
  setUpAll(loadAppFonts);

  Future<FakeAuthRepository> pumpApp(
    WidgetTester tester, {
    String themeMode = 'light',
    bool onboarded = true,
    // Simulated status-bar height. Zero by default, which is also what the
    // test surface defaults to unasked — meaning a test that never sets this
    // cannot tell a real inset from none at all. See the test that does.
    double topInset = 0,
    // The welcome artwork is full-bleed 9:16, so these tests need a phone
    // rather than the default 800x600 landscape window.
    Size surface = const Size(393, 852),
  }) async {
    SharedPreferences.setMockInitialValues({
      ThemeModeController.prefsKey: themeMode,
    });
    final prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthRepository();

    tester.view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1.0
      ..padding = FakeViewPadding(top: topInset);
    addTearDown(tester.view.reset);

    tester.view
      ..physicalSize = surface
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
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    return auth;
  }

  /// The hit area over the button drawn into a slide's artwork.
  ///
  /// Matched on the Semantics *widget* rather than with `bySemanticsLabel`:
  /// that finder resolves to the merged route-level node, whose box is the
  /// whole screen, so tapping it lands in the middle of the picture and misses
  /// the button entirely.
  Finder slideButton(String action) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == action,
  );

  Future<void> tapSlideButton(WidgetTester tester, String action) async {
    await tester.tap(slideButton(action));
    await tester.pumpAndSettle();
  }

  /// Walks the carousel to the last slide and taps through to sign-in.
  Future<void> reachMobileScreen(WidgetTester tester) async {
    for (final slide in WelcomeScreen.slides) {
      await tapSlideButton(tester, slide.action);
    }
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
      // The artwork carries its own headline and body, so there is nothing to
      // find as text — the drawn button's name is the only string this screen
      // still owns.
      expect(slideButton(WelcomeScreen.slides.first.action), findsOneWidget);
    });

    testWidgets('advances through all four slides', (tester) async {
      await pumpApp(tester);

      for (final slide in WelcomeScreen.slides.take(3)) {
        await tapSlideButton(tester, slide.action);
      }

      expect(slideButton('Start Wishticking'), findsOneWidget);
      // And the earlier slides are gone rather than stacked behind it.
      expect(slideButton('Create Wishlist'), findsNothing);
    });

    testWidgets('every slide names its own button, so a reader can act on '
        'artwork it cannot read', (tester) async {
      await pumpApp(tester);

      for (final slide in WelcomeScreen.slides) {
        expect(
          slideButton(slide.action),
          findsOneWidget,
          reason: '${slide.figmaNodeId} has no reachable button',
        );
        if (slide != WelcomeScreen.slides.last) {
          await tapSlideButton(tester, slide.action);
        }
      }
    });

    testWidgets('leads into the sign-in screen', (tester) async {
      await pumpApp(tester);
      await reachMobileScreen(tester);

      expect(find.byType(MobileNumberScreen), findsOneWidget);
      expect(find.text('Ready to Celebrate?'), findsOneWidget);
    });

    testWidgets('the hit area sits on the button drawn into the artwork', (
      tester,
    ) async {
      await pumpApp(tester);

      // The whole point of the approach: a rect measured off the picture. If
      // it drifted to the middle of the screen every tap would still "work"
      // in a test that only counts taps, so this pins *where* it is.
      final slide = WelcomeScreen.slides.first;
      final screen = tester.getRect(find.byType(WelcomeScreen));
      final hit = tester.getRect(
        find.descendant(
          of: slideButton(slide.action),
          matching: find.byType(GestureDetector),
        ),
      );

      // Low on the screen, where every one of the four designs draws it.
      expect(hit.center.dy / screen.height, greaterThan(0.80));
      expect(hit.center.dy / screen.height, lessThan(0.98));
      // And roughly button-shaped rather than a stray full-screen box — the
      // failure mode when a finder resolves to a merged semantics node.
      expect(hit.width, lessThan(screen.width));
      expect(hit.height, lessThan(screen.height * 0.15));
      expect(hit.height, greaterThan(24));
    });

    testWidgets('the artwork fills the screen at every aspect ratio, and the '
        'button hit area follows it', (tester) async {
      // `cover`, so the artwork reaches every edge and the shortfall is a crop
      // rather than a letterbox. What that costs is real — the 9:16 design
      // loses ~11% off each side on a 20:9 phone — and is the reason the
      // slides want redrawing on a taller canvas. What it must not cost is the
      // button: its position is a fraction of the *image*, and under cover the
      // image starts outside the screen.
      for (final surface in const [
        Size(393, 852), // a tall phone, 20:9
        Size(1000, 800), // a tablet, wider than the art
        Size(360, 640), // 9:16 exactly
      ]) {
        await pumpApp(tester, surface: surface);

        // The fit itself, because `getRect` on the Image returns its *box* —
        // the whole screen under either fit — and so cannot tell a cropped
        // painting from a letterboxed one.
        expect(
          tester.widget<Image>(find.byType(Image).first).fit,
          BoxFit.cover,
          reason: '$surface',
        );

        final hit = tester.getRect(
          find.descendant(
            of: slideButton(WelcomeScreen.slides.first.action),
            matching: find.byType(GestureDetector),
          ),
        );

        // Where the covered artwork actually lands: bigger than the screen on
        // one axis, centred, so its origin is negative there. Getting this
        // backwards is the bug that leaves a tappable area beside the button
        // instead of on it — and it grows with the screen, so a 9:16 test
        // surface alone would never show it.
        final art = WelcomeScreen.artworkAspectRatio;
        final boxAspect = surface.width / surface.height;
        final drawnWidth = boxAspect > art
            ? surface.width
            : surface.height * art;
        final originX = (surface.width - drawnWidth) / 2;
        expect(
          hit.left,
          closeTo(
            originX + WelcomeScreen.slides.first.button.left * drawnWidth,
            0.5,
          ),
          reason: '$surface',
        );
        expect(
          hit.width,
          closeTo(
            (WelcomeScreen.slides.first.button.right -
                    WelcomeScreen.slides.first.button.left) *
                drawnWidth,
            0.5,
          ),
          reason: '$surface',
        );
      }
    });

    testWidgets('the canvas behind the artwork is the white it ends in', (
      tester,
    ) async {
      await pumpApp(tester, surface: const Size(393, 852));

      // Under `cover` this is no longer a letterbox — the artwork reaches
      // every edge — but it is still what shows for the frame before a slide
      // finishes decoding, and every slide's outer rows are pure white (see
      // welcome_artwork_test.dart). Anything else flashes a coloured slab on
      // the first screen of the app.
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        WishtickColors.light.artworkCanvas,
      );
      expect(WishtickColors.light.artworkCanvas, const Color(0xFFFFFFFF));
      // And it must not follow the theme: the artwork cannot.
      expect(
        WishtickColors.dark.artworkCanvas,
        WishtickColors.light.artworkCanvas,
      );
    });

    testWidgets('the status bar icons are dark, because the artwork behind '
        'them is light', (tester) async {
      await pumpApp(tester, topInset: 40);

      // The status bar sits over the artwork itself now that it is covered
      // rather than letterboxed, and all four designs are light at the top —
      // so dark icons are what read against them. They also read against the
      // white canvas behind, for the frame before the image decodes.
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(region.value, SystemUiOverlayStyle.dark);
    });

    testWidgets('nothing is drawn over the artwork', (tester) async {
      await pumpApp(tester);

      // The headline, body and button are all in the picture. A Text or a
      // painted button here would double whatever the artwork already says —
      // which is exactly what the previous layout did.
      expect(
        find.descendant(
          of: find.byType(WelcomeScreen),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(WelcomeScreen),
          matching: find.byType(ElevatedButton),
        ),
        findsNothing,
      );
    });
  });

  group('mobile number screen', () {
    testWidgets('the page is the app beige, not white', (tester) async {
      await pumpApp(tester);
      await reachMobileScreen(tester);

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        WishtickColors.light.background,
      );
    });

    testWidgets('the sparkle badge icon stays small, on the app icon-size '
        'scale rather than a stray literal', (tester) async {
      await pumpApp(tester);
      await reachMobileScreen(tester);

      final icon = tester.widget<ImageIcon>(find.byType(ImageIcon));
      expect(icon.size, AppSizes.iconSm);
    });

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

    /// The documents open in the app, not the browser: someone deciding
    /// whether to agree should not be thrown out of the screen they are
    /// agreeing on, and should see the terms this build actually ships with.
    testWidgets('the consent links open the documents in the app', (
      tester,
    ) async {
      await pumpApp(tester);
      await reachMobileScreen(tester);

      await tester.tapOnText(find.textRange.ofSubstring('Terms & Conditions*'));
      await tester.pumpAndSettle();
      expect(find.byType(LegalDocumentScreen), findsOneWidget);
      expect(find.text('40 sections'), findsOneWidget);

      await tester.tap(find.byType(CircleBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(MobileNumberScreen), findsOneWidget);

      await tester.tapOnText(find.textRange.ofSubstring('Privacy policy*'));
      await tester.pumpAndSettle();
      expect(find.text('41 sections'), findsOneWidget);
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
    Future<FakeAuthRepository> reachOtp(
      WidgetTester tester, {
      String? devCode,
    }) async {
      final auth = await pumpApp(tester);
      auth.nextDevCode = devCode;
      await reachMobileScreen(tester);
      await enterNumber(tester, '9876543210');
      await acceptTerms(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'GET OTP'));
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('the page is the app beige, not white', (tester) async {
      await reachOtp(tester);

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        WishtickColors.light.background,
      );
    });

    /// Pins the constant to the backend's actual `OTP_LENGTH=4` rather than
    /// deriving from it, which is the one thing the tests below cannot do —
    /// every other assertion here is written in terms of `otpLength`, so a
    /// drift between the two would pass them all against a screen that could
    /// never accept a real code. Only a literal catches it.
    test('the code length matches the backend contract', () {
      expect(AuthRepository.otpLength, 4);
    });

    testWidgets('renders one box per digit of the backend code length', (
      tester,
    ) async {
      await reachOtp(tester);

      // Matches OTP_LENGTH and the screen's own "N-digit code" copy.
      expect(
        find.text(
          'We sent a ${AuthRepository.otpLength}-digit code to your phone',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxWidth == 48,
        ),
        findsNWidgets(AuthRepository.otpLength),
      );
    });

    testWidgets('shows the code inline when the API sent one (dev/staging '
        'only)', (tester) async {
      await reachOtp(tester, devCode: '482913');

      expect(find.text('Dev OTP: 482913'), findsOneWidget);
    });

    testWidgets('shows nothing extra when the API sent no code — the '
        'production case', (tester) async {
      await reachOtp(tester);

      expect(find.textContaining('Dev OTP'), findsNothing);
    });

    testWidgets('shows the number and a resend countdown', (tester) async {
      await reachOtp(tester);

      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('edit'), findsOneWidget);
      expect(find.textContaining('Resend code in'), findsOneWidget);
    });

    testWidgets('verifies automatically once the code is complete', (
      tester,
    ) async {
      final auth = await reachOtp(tester);
      final code = '1' * AuthRepository.otpLength;

      await tester.enterText(find.byType(TextField).first, code);
      await tester.pumpAndSettle();

      expect(auth.verifiedSignIns.single.code, code);
      // A returning, onboarded user lands straight on the tab shell.
      expect(find.byType(WishtickBottomNav), findsOneWidget);
    });

    testWidgets('a brand-new account goes to onboarding, not the shell', (
      tester,
    ) async {
      final auth = await reachOtp(tester);
      auth.nextIsNewUser = true;

      await tester.enterText(
        find.byType(TextField).first,
        '1' * AuthRepository.otpLength,
      );
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

      await tester.enterText(
        find.byType(TextField).first,
        '0' * AuthRepository.otpLength,
      );
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
