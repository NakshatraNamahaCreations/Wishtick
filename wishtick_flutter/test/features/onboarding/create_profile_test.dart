import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/app.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/theme/theme_controller.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_swipe_button.dart';
import 'package:wishtick_flutter/features/auth/data/auth_repository.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/onboarding/domain/profile_draft.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/avatar_picker_screen.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/create_profile_screen.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/interests_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/onboarding_fakes.dart';
import '../../helpers/swipe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FakeOnboardingRepository> pumpOnboarding(
    WidgetTester tester, {
    String themeMode = 'light',
  }) async {
    SharedPreferences.setMockInitialValues({
      ThemeModeController.prefsKey: themeMode,
    });
    final prefs = await SharedPreferences.getInstance();
    final onboarding = FakeOnboardingRepository();

    tester.view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // A stored session that has not finished onboarding, which is exactly
          // where the router should hold the user.
          tokenStorageProvider.overrideWithValue(
            FakeTokenStorage(refreshToken: 'refresh'),
          ),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          onboardingRepositoryProvider.overrideWithValue(onboarding),
        ],
        child: const WishtickApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    return onboarding;
  }

  Finder fieldWithHint(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint,
  );

  /// The avatar tile for a 1-based index, located by its bundled asset.
  Finder avatarTile(int index) {
    final asset = BundledAvatar(index).asset;
    return find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == asset,
    );
  }

  /// The form is taller than the viewport, so anything below the fold has to be
  /// scrolled to before it can be tapped.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> typeInto(WidgetTester tester, Finder finder, String text) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  /// Fills every required field so Continue becomes enabled.
  Future<void> fillForm(
    WidgetTester tester, {
    String name = 'Ananya Mehra',
    String email = 'ananya@example.com',
  }) async {
    await typeInto(tester, fieldWithHint('Enter your full name'), name);
    await typeInto(tester, fieldWithHint('Enter your Email ID'), email);

    // The date field opens a picker; OK accepts the default (25 years ago).
    await tapVisible(tester, find.text('dd/mm/yyyy'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Female'));
  }

  group('layout', () {
    testWidgets('shows the design’s header, copy and fields', (tester) async {
      await pumpOnboarding(tester);

      expect(find.byType(CreateProfileScreen), findsOneWidget);
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Create Your Profile'), findsOneWidget);
      expect(find.text("A few details and you're in."), findsOneWidget);
      expect(find.text('Select Avatar'), findsOneWidget);
      expect(find.text('Or'), findsOneWidget);

      // Labels are rich text — "Email ID" plus a red asterisk — so they need the
      // rich-text finder, and matching the whole string keeps "Email ID" from
      // also hitting the "Enter your Email ID" hint.
      for (final label in [
        'Your Name',
        'Email ID',
        'Date of Birth',
        'Gender',
      ]) {
        expect(
          find.text('$label *', findRichText: true),
          findsOneWidget,
          reason: '$label label is missing',
        );
      }
      for (final gender in Gender.values) {
        expect(find.text(gender.label), findsOneWidget);
      }
    });
  });

  group('validation', () {
    // The design shows the track plum and live on an empty form, so it is
    // never disabled by incompleteness — swiping has to say what is missing.
    testWidgets('an empty form reports every missing field rather than doing '
        'nothing', (tester) async {
      final onboarding = await pumpOnboarding(tester);

      expect(
        tester
            .widget<WishtickSwipeButton>(find.byType(WishtickSwipeButton))
            .onSwiped,
        isNotNull,
        reason: 'the track must be live on an empty form',
      );

      await swipeToContinue(tester);

      expect(onboarding.savedProfiles, isEmpty, reason: 'nothing to save yet');
      for (final message in [
        'Please enter your email',
        'Please choose your date of birth',
        'Please select your gender',
      ]) {
        expect(find.text(message), findsOneWidget, reason: message);
      }
      // Name is seeded from the signed-in user, so it is already valid and
      // must not be reported as missing.
      expect(find.text('Please enter your name'), findsNothing);
    });

    testWidgets('a malformed email is called out under the email field', (
      tester,
    ) async {
      final onboarding = await pumpOnboarding(tester);
      await fillForm(tester, email: 'not-an-email');

      await swipeToContinue(tester);
      await tester.pumpAndSettle();

      expect(onboarding.savedProfiles, isEmpty);
      expect(
        find.text("That doesn't look like an email address"),
        findsOneWidget,
      );
      // The fields that *were* filled stay quiet.
      expect(find.text('Please enter your name'), findsNothing);
    });

    testWidgets('errors clear as soon as the field is corrected', (
      tester,
    ) async {
      await pumpOnboarding(tester);

      await swipeToContinue(tester);
      await tester.pumpAndSettle();
      expect(find.text('Please enter your email'), findsOneWidget);

      await typeInto(
        tester,
        fieldWithHint('Enter your Email ID'),
        'ananya@example.com',
      );
      expect(find.text('Please enter your email'), findsNothing);
    });
  });

  group('submitting', () {
    testWidgets('sends everything the screen collects', (tester) async {
      final onboarding = await pumpOnboarding(tester);
      await fillForm(tester);

      await swipeToContinue(tester);

      final draft = onboarding.savedProfiles.single;
      expect(draft.name, 'Ananya Mehra');
      expect(draft.email, 'ananya@example.com');
      expect(draft.gender, Gender.female);
      expect(draft.dateOfBirthIso, isNotNull);
    });

    testWidgets('advances to the interests step once saved', (tester) async {
      await pumpOnboarding(tester);
      await fillForm(tester);

      await swipeToContinue(tester);

      expect(find.byType(InterestsScreen), findsOneWidget);
      expect(find.byType(CreateProfileScreen), findsNothing);
    });

    testWidgets('keeps the user on the form when the save fails', (
      tester,
    ) async {
      final onboarding = await pumpOnboarding(tester);
      onboarding.saveFailure = const ApiException(
        code: 'EMAIL_ALREADY_REGISTERED',
        message: 'taken',
        statusCode: 409,
      );
      await fillForm(tester);

      await swipeToContinue(tester);

      expect(find.byType(CreateProfileScreen), findsOneWidget);
      expect(
        find.text('That email is already used by another account.'),
        findsOneWidget,
      );
      expect(find.text('Already used by another account'), findsOneWidget);
    });
  });

  group('avatar picker', () {
    testWidgets('opens with all twenty avatars', (tester) async {
      await pumpOnboarding(tester);

      await tapVisible(tester, find.text('Select Avatar'));

      expect(find.byType(AvatarPickerScreen), findsOneWidget);
      expect(find.text('Select Your Avatar'), findsOneWidget);
      // Scrolling would be needed to render all twenty, so assert on the model
      // plus the tiles the first viewport builds.
      expect(BundledAvatar.all, hasLength(20));
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('the swipe track is dead until an avatar is chosen', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await tapVisible(tester, find.text('Select Avatar'));

      expect(
        tester
            .widget<WishtickSwipeButton>(find.byType(WishtickSwipeButton))
            .onSwiped,
        isNull,
      );

      // And a full swipe on a dead track goes nowhere.
      await swipeToContinue(tester);
      expect(find.byType(AvatarPickerScreen), findsOneWidget);
    });

    testWidgets('a chosen avatar comes back to the profile form', (
      tester,
    ) async {
      final onboarding = await pumpOnboarding(tester);
      await tapVisible(tester, find.text('Select Avatar'));

      await tapVisible(tester, avatarTile(3));
      await swipeToContinue(tester);

      expect(find.byType(CreateProfileScreen), findsOneWidget);

      await fillForm(tester);
      await swipeToContinue(tester);

      expect(onboarding.savedProfiles.single.avatar?.key, 'avatar_03');
    });
  });

  group('dark palette', () {
    // Built straight on AppTheme.dark rather than through a stored preference:
    // the app is light-only for now (kDarkModeEnabled), so a 'dark' pref no
    // longer changes anything. The palette itself is still live — the memory
    // story reads it — and this is what keeps the screen laying out on it.
    testWidgets('renders without overflow', (tester) async {
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
            onboardingRepositoryProvider.overrideWithValue(
              FakeOnboardingRepository(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const CreateProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(CreateProfileScreen));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    });
  });
}
