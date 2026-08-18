import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/app.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/core/theme/app_colors.dart';
import 'package:wishtick_flutter/core/theme/app_dimens.dart';
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

    /// The 6×6 circular dots, in tree order — distinguished from any other
    /// circular decoration on the page by that fixed size.
    List<Color?> dotColors(WidgetTester tester) {
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

    testWidgets('the dots track the current slide', (tester) async {
      await pumpApp(tester);
      final colors = WishtickColors.light;

      expect(dotColors(tester), [
        colors.primary,
        colors.border,
        colors.border,
        colors.border,
      ]);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(dotColors(tester), [
        colors.border,
        colors.primary,
        colors.border,
        colors.border,
      ]);
    });

    testWidgets(
      'the dots are grouped with the body copy, not a separate sibling '
      'below the whole slide',
      (tester) async {
        await pumpApp(tester);

        // Regression guard: the dots used to be a sibling *after* a PageView
        // whose page centred headline+body within its full height — so the
        // gap to the dots was mostly empty flex space, not a fixed distance,
        // and grew or shrank with device height. Asserting the dots live
        // inside the same scrollable as the body text pins the structural
        // fix (see the note in welcome_screen.dart) rather than a raw pixel
        // gap, which shifts under any unrelated layout change.
        final slideScrollable = find.ancestor(
          of: find.text(
            'Create your personal wishlist and help your loved ones '
            "choose gifts you'll truly cherish.",
          ),
          matching: find.byType(SingleChildScrollView),
        );
        expect(
          find.descendant(of: slideScrollable, matching: find.byType(Row)),
          findsOneWidget,
          reason: 'the dots row should be inside the slide, not after it',
        );
      },
    );

    testWidgets(
      'the dots sit right above Continue — the fixed gap only, no leftover '
      'centring slack',
      (tester) async {
        await pumpApp(tester);

        // Regression guard for a second bug the fix above didn't catch on
        // its own: a Column's mainAxisAlignment does nothing inside a
        // SingleChildScrollView (the scroll view hands it unbounded height,
        // so it always shrink-wraps to the top) — so grouping the dots with
        // the text still left slack piling up *below* them, between the
        // dots and the button, instead of above the headline where it
        // belongs. The fix needs a LayoutBuilder + ConstrainedBox for
        // `end` alignment to have anywhere to push into — see the note in
        // welcome_screen.dart.
        final dotsBottom = tester.getBottomLeft(find.byType(Row).last).dy;
        final buttonTop = tester
            .getTopLeft(find.widgetWithText(ElevatedButton, 'Continue'))
            .dy;

        // AppSpacing.xl (20) is the *only* fixed gap between them; a few
        // pixels either side covers font-metric rounding, not slack.
        expect(buttonTop - dotsBottom, closeTo(20, 4));
      },
    );

    testWidgets(
      'the hero image keeps its size regardless of the status bar inset',
      (tester) async {
        // Regression guard for a bug the *previous* fix introduced: wrapping
        // the whole screen in SafeArea shrank the image's box by the inset,
        // and BoxFit.cover needed less crop to fill a shorter box — exposing
        // a flat band near the subject's lap that the original crop was
        // hiding. The image must render at the *same* size whether or not a
        // status bar is present; legibility over it is a scrim's job (the
        // next test), not the image's own size.
        const inset = 40.0;

        await pumpApp(tester);
        final heightNoInset = tester.getSize(find.byType(Image)).height;

        await pumpApp(tester, topInset: inset);
        final heightWithInset = tester.getSize(find.byType(Image)).height;

        expect(heightWithInset, heightNoInset);
      },
    );

    testWidgets(
      'a scrim covers the status bar area so its icons stay legible over '
      'the photo',
      (tester) async {
        const inset = 40.0;
        await pumpApp(tester, topInset: inset);

        // The image runs full-bleed under the status bar on purpose (see the
        // test above) — legibility comes from a gradient sized to the inset,
        // not from pushing the photo down.
        final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        );
        expect(
          region.value,
          SystemUiOverlayStyle.light,
          reason: 'icons need to read against the scrim, not the photo',
        );

        final scrim = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(Stack),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(scrim.constraints?.maxHeight, inset);
        expect(
          (scrim.decoration! as BoxDecoration).gradient,
          isA<LinearGradient>(),
        );
      },
    );

    testWidgets(
      'the hero photo fades into the page colour at its bottom edge, not a '
      'hard cut',
      (tester) async {
        await pumpApp(tester);

        final fade = tester.widget<FractionallySizedBox>(
          find.descendant(
            of: find.byType(Stack),
            matching: find.byType(FractionallySizedBox),
          ),
        );
        expect(
          fade.heightFactor,
          0.12,
          reason: 'matches the fade sampled from the Figma export',
        );

        final decoratedBox = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(FractionallySizedBox),
            matching: find.byType(DecoratedBox),
          ),
        );
        final gradient =
            (decoratedBox.decoration as BoxDecoration).gradient!
                as LinearGradient;
        expect(
          gradient.colors.first,
          WishtickColors.light.background.withValues(alpha: 0),
        );
        expect(gradient.colors.last, WishtickColors.light.background);
      },
    );

    testWidgets('the page is the app beige, not white', (tester) async {
      await pumpApp(tester);

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        WishtickColors.light.background,
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

    testWidgets('the page is the app beige, not white', (tester) async {
      await reachOtp(tester);

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        WishtickColors.light.background,
      );
    });

    /// Pins the constant to the server's own default rather than deriving from
    /// it, which is the one thing the tests below cannot do.
    ///
    /// It read 4 while `OTP_LENGTH` defaulted to 6, and every other assertion
    /// here is written in terms of `otpLength` — so they all passed against a
    /// screen that could never accept a real code. Only a literal catches it.
    test('the code length matches the backend contract', () {
      expect(AuthRepository.otpLength, 6);
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
