import 'package:flutter/material.dart';
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
    await tester.pump(const Duration(seconds: 5));
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

    // Only the calendar icon opens the picker now — the box itself is a real
    // TextField for manual entry. OK accepts the default (25 years ago).
    await tapVisible(tester, find.byIcon(Icons.calendar_today_outlined));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Female'));
  }

  group('gender tiles', () {
    /// The tile's own filled box, found by the label it wraps.
    BoxDecoration decorationFor(WidgetTester tester, String label) {
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      return container.decoration! as BoxDecoration;
    }

    testWidgets('are flat white with no border until chosen', (tester) async {
      await pumpOnboarding(tester);
      await tester.ensureVisible(find.text('Female'));
      await tester.pumpAndSettle();

      final colors = WishtickColors.light;
      for (final label in ['Male', 'Female', 'Other']) {
        final decoration = decorationFor(tester, label);
        expect(decoration.color, colors.surface, reason: '$label fill');
        // Matches the Figma design exactly — no hairline, unlike the "Select
        // Avatar" card above it.
        expect(decoration.border, isNull, reason: '$label border');
      }
    });

    testWidgets('the chosen one fills with plum instead', (tester) async {
      await pumpOnboarding(tester);
      await tester.ensureVisible(find.text('Female'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();

      final colors = WishtickColors.light;
      expect(decorationFor(tester, 'Female').color, colors.primary);
      expect(decorationFor(tester, 'Male').color, colors.surface);
    });

    testWidgets('Male and Female use Material glyphs, Other the brand asset', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await tester.ensureVisible(find.text('Female'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.male), findsOneWidget);
      expect(find.byIcon(Icons.female), findsOneWidget);
      final image = tester.widget<ImageIcon>(find.byType(ImageIcon));
      expect((image.image as AssetImage).assetName, 'assets/icons/others.png');
    });

    testWidgets(
      'a tile is compact — a shorter box, more rounded, with a bigger icon '
      'set tighter above its label',
      (tester) async {
        await pumpOnboarding(tester);
        await tester.ensureVisible(find.text('Female'));
        await tester.pumpAndSettle();

        final tile = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Female'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(tile.constraints?.maxHeight, 72);
        expect(
          (tile.decoration! as BoxDecoration).borderRadius,
          BorderRadius.circular(AppRadius.xl),
        );

        final iconTheme = tester.widget<IconTheme>(
          find
              .ancestor(
                of: find.byIcon(Icons.female),
                matching: find.byType(IconTheme),
              )
              .first,
        );
        expect(iconTheme.data.size, AppSizes.iconLg);

        final iconBottom = tester.getBottomLeft(find.byIcon(Icons.female)).dy;
        final labelTop = tester.getTopLeft(find.text('Female')).dy;
        expect(labelTop - iconBottom, closeTo(AppSpacing.sm, 2));
      },
    );
  });

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

    testWidgets('the text fields cast a soft shadow, lifting them off the '
        'page', (tester) async {
      await pumpOnboarding(tester);

      // Name, Email and Date of Birth are meant to read as one matching set
      // (see the note in _FieldShadow) — checking all three catches a
      // regression that only wraps some of them.
      for (final finder in [
        fieldWithHint('Enter your full name'),
        fieldWithHint('Enter your Email ID'),
        find.text('dd/mm/yyyy'),
      ]) {
        // The Date of Birth field's own Container paints a nearer
        // DecoratedBox (its fill) than the shadow wrapper around it, so this
        // looks across every DecoratedBox ancestor for the one actually
        // carrying a shadow rather than assuming it is the closest.
        final ancestors = find.ancestor(
          of: finder,
          matching: find.byType(DecoratedBox),
        );
        final hasShadow = ancestors.evaluate().any((element) {
          final decoration =
              (element.widget as DecoratedBox).decoration as BoxDecoration;
          final shadow = decoration.boxShadow;
          return shadow != null && shadow.isNotEmpty;
        });
        expect(hasShadow, isTrue, reason: 'no shadow found above $finder');
      }
    });

    testWidgets('the Date of Birth box has no border, unlike Name and Email', (
      tester,
    ) async {
      await pumpOnboarding(tester);

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: fieldWithHint('dd/mm/yyyy'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((container.decoration! as BoxDecoration).border, isNull);

      // The outer Container carrying no border isn't enough on its own — the
      // app's InputDecorationTheme draws its own enabledBorder/focusedBorder
      // on every TextField unless the field overrides all three explicitly,
      // and that hairline is what a Container-only check would miss.
      final field = tester.widget<TextField>(fieldWithHint('dd/mm/yyyy'));
      for (final border in [
        field.decoration?.border,
        field.decoration?.enabledBorder,
        field.decoration?.focusedBorder,
      ]) {
        expect(border, InputBorder.none);
      }
    });

    testWidgets('the gap between fields is a tight fixed gap, not the old '
        'double-height space', (tester) async {
      await pumpOnboarding(tester);
      final emailLabel = find.text('Email ID *', findRichText: true);
      await tester.ensureVisible(emailLabel);
      await tester.pumpAndSettle();

      final fieldBottom = tester
          .getBottomLeft(fieldWithHint('Enter your full name'))
          .dy;
      final nextLabelTop = tester.getTopLeft(emailLabel).dy;

      expect(nextLabelTop - fieldBottom, closeTo(20, 4));
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

  group('date of birth entry', () {
    testWidgets('tapping the box opens the keyboard, not the calendar', (
      tester,
    ) async {
      await pumpOnboarding(tester);

      await tapVisible(tester, fieldWithHint('dd/mm/yyyy'));

      expect(
        find.text('OK'),
        findsNothing,
        reason: 'tapping the text should never pop the date picker',
      );
    });

    testWidgets('only the calendar icon opens the picker', (tester) async {
      await pumpOnboarding(tester);

      await tapVisible(tester, find.byIcon(Icons.calendar_today_outlined));

      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('typed digits are auto-formatted into dd/mm/yyyy', (
      tester,
    ) async {
      await pumpOnboarding(tester);

      await typeInto(tester, fieldWithHint('dd/mm/yyyy'), '18082001');

      expect(
        tester.widget<TextField>(fieldWithHint('dd/mm/yyyy')).controller?.text,
        '18/08/2001',
      );
    });

    testWidgets('a complete, valid typed date saves correctly', (tester) async {
      final onboarding = await pumpOnboarding(tester);
      await typeInto(
        tester,
        fieldWithHint('Enter your Email ID'),
        'ananya@example.com',
      );
      await typeInto(tester, fieldWithHint('dd/mm/yyyy'), '18082001');
      await tapVisible(tester, find.text('Female'));

      await swipeToContinue(tester);

      expect(onboarding.savedProfiles.single.dateOfBirthIso, '2001-08-18');
    });

    testWidgets(
      "a date that doesn't exist is called out, not silently accepted",
      (tester) async {
        final onboarding = await pumpOnboarding(tester);

        // February never has 31 days.
        await typeInto(tester, fieldWithHint('dd/mm/yyyy'), '31022020');

        expect(
          find.text("That date doesn't exist — check the day and month"),
          findsOneWidget,
        );

        await swipeToContinue(tester);
        expect(onboarding.savedProfiles, isEmpty);
      },
    );

    testWidgets('a birth date in the future is called out', (tester) async {
      await pumpOnboarding(tester);

      await typeInto(tester, fieldWithHint('dd/mm/yyyy'), '01012099');

      expect(find.text("That's still in the future"), findsOneWidget);
    });

    testWidgets(
      'erasing back to an incomplete date drops the stale commit, not '
      'just the display',
      (tester) async {
        final onboarding = await pumpOnboarding(tester);
        await typeInto(tester, fieldWithHint('dd/mm/yyyy'), '18082001');

        // Back down to five digits — no longer a complete date.
        await typeInto(tester, fieldWithHint('dd/mm/yyyy'), '18/08');

        await swipeToContinue(tester);

        expect(onboarding.savedProfiles, isEmpty);
        expect(find.text('Please choose your date of birth'), findsOneWidget);
      },
    );
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

    testWidgets('opens with the default already chosen, so Continue is live', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await tapVisible(tester, find.text('Select Avatar'));

      // The form seeds [BundledAvatar.defaultChoice], and the picker starts on
      // whatever the form holds — so there is no dead-track state to sit in.
      // The track used to be dead here, which was the visible half of a worse
      // problem: the profile screen drew avatar_01 either way, so somebody
      // could back out believing they had chosen it and save nothing.
      expect(
        tester
            .widget<WishtickSwipeButton>(find.byType(WishtickSwipeButton))
            .onSwiped,
        isNotNull,
      );

      // Continuing without touching a tile keeps the default rather than
      // dropping it — this is the path most accounts actually take.
      await swipeToContinue(tester);
      expect(find.byType(CreateProfileScreen), findsOneWidget);
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
