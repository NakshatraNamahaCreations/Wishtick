import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/app.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/core/theme/theme_controller.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_bottom_nav.dart';
import 'package:wishtick_flutter/features/auth/data/auth_repository.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/all_set_screen.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/category_detail_screen.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/colors_screen.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/create_profile_screen.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/important_dates_screen.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/interests_screen.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/size_fit_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/onboarding_fakes.dart';
import '../../helpers/swipe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FakeOnboardingRepository> pumpFlow(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      ThemeModeController.prefsKey: 'light',
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

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  /// Completes step 1 (Create Profile) to land on the interests grid.
  Future<void> completeProfileStep(WidgetTester tester) async {
    await tester.enterText(
      fieldWithHint('Enter your full name'),
      'Ananya Mehra',
    );
    await tapVisible(tester, fieldWithHint('Enter your Email ID'));
    await tester.enterText(
      fieldWithHint('Enter your Email ID'),
      'ananya@example.com',
    );
    await tester.pumpAndSettle();
    // Only the calendar icon opens the picker now — the box itself is a real
    // TextField for manual entry.
    await tapVisible(tester, find.byIcon(Icons.calendar_today_outlined));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Female'));
    await swipeToContinue(tester);
  }

  testWidgets('a new user walks profile → interests → details → colours → '
      'sizes → dates → all set → shell', (tester) async {
    final onboarding = await pumpFlow(tester);

    // Step 1 — Create Profile (already covered in depth elsewhere).
    expect(find.byType(CreateProfileScreen), findsOneWidget);
    await completeProfileStep(tester);

    // Step 2 — interests grid from the fake's catalogue.
    expect(find.byType(InterestsScreen), findsOneWidget);
    expect(find.text('Tell us what you love'), findsOneWidget);
    expect(find.text('Step 2 of 5'), findsOneWidget);

    await tapVisible(tester, find.text('Fashion & Personal Style'));
    await tapVisible(tester, find.text('Technology & Gadgets'));
    expect(find.textContaining('(2/2)', findRichText: true), findsOneWidget);
    await swipeToContinue(tester);

    // Detail screen for the first category, in selection order.
    expect(find.byType(CategoryDetailScreen), findsOneWidget);
    expect(find.text('Fashion & Personal Style'), findsOneWidget);
    await tapVisible(tester, find.text('Shoes'));
    await swipeToContinue(tester);

    // Second category's detail.
    expect(find.text('Technology & Gadgets'), findsOneWidget);
    await tapVisible(tester, find.text('Gaming'));
    await swipeToContinue(tester);

    // Step 2 saved with everything collected (field-by-field: records holding
    // Lists compare by identity).
    expect(onboarding.savedInterests?.categories, ['fashion', 'technology']);
    expect(onboarding.savedInterests?.interests, [
      'fashion_shoes',
      'tech_gaming',
    ]);
    expect(onboarding.savedInterests?.customs, isEmpty);

    // Step 3 — colours.
    expect(find.byType(ColorsScreen), findsOneWidget);
    expect(find.text('Step 3 of 5'), findsOneWidget);
    await tapVisible(tester, find.text('Plum'));
    await swipeToContinue(tester);
    expect(onboarding.savedColors, ['purple_plum']);

    // Step 4 — size & fit.
    expect(find.byType(SizeFitScreen), findsOneWidget);
    expect(find.text('Step 4 of 5'), findsOneWidget);
    await tapVisible(tester, find.text('XS'));
    await tapVisible(tester, find.text('Regular'));
    expect(
      find.textContaining('Clothing: XS', findRichText: true),
      findsOneWidget,
    );
    await swipeToContinue(tester);
    expect(onboarding.savedSizes, (clothing: 'xs', shoe: null, fit: 'regular'));

    // Step 5 — important dates; save one then continue.
    expect(find.byType(ImportantDatesScreen), findsOneWidget);
    expect(find.text('Step 5 of 5'), findsOneWidget);
    await tester.enterText(fieldWithHint('e.g. Ananya, Rahul'), 'Rahul');
    await tester.enterText(fieldWithHint('e.g. Mom, Best Friend'), 'Brother');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Birthday').last);
    await tapVisible(tester, find.text('Birthday').last);
    // Only the calendar icon opens the picker now — the box itself is a
    // real TextField for manual entry.
    await tapVisible(tester, find.byIcon(Icons.calendar_today_outlined));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save Date'));
    expect(onboarding.dates.single.personName, 'Rahul');

    await swipeToContinue(tester);

    // All set → Explore Wishtick → the tab shell.
    expect(find.byType(AllSetScreen), findsOneWidget);
    expect(onboarding.completed, isTrue);
    await tapVisible(tester, find.text('Explore Wishtick'));

    expect(find.byType(WishtickBottomNav), findsOneWidget);
  });

  testWidgets('SKIP on the interests grid jumps to colours saving nothing', (
    tester,
  ) async {
    final onboarding = await pumpFlow(tester);
    await completeProfileStep(tester);

    await tapVisible(tester, find.text('SKIP'));

    expect(find.byType(ColorsScreen), findsOneWidget);
    expect(onboarding.savedInterests, isNull);
  });

  testWidgets('skipping every step still completes onboarding', (tester) async {
    final onboarding = await pumpFlow(tester);
    await completeProfileStep(tester);

    await tapVisible(tester, find.text('SKIP')); // interests → colours
    await tapVisible(tester, find.text('SKIP')); // colours → sizes
    await tapVisible(tester, find.text('SKIP')); // sizes → dates
    await tapVisible(tester, find.text('SKIP')); // dates → complete

    expect(find.byType(AllSetScreen), findsOneWidget);
    expect(onboarding.completed, isTrue);
    expect(onboarding.savedInterests, isNull);
    expect(onboarding.savedColors, isNull);
    expect(onboarding.savedSizes, isNull);
  });
}
