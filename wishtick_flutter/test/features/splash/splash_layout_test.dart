import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/app.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/core/theme/theme_controller.dart';
import 'package:wishtick_flutter/features/auth/data/auth_repository.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/load_app_fonts.dart';
import '../../helpers/onboarding_fakes.dart';

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
    SharedPreferences.setMockInitialValues({
      ThemeModeController.prefsKey: 'light',
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
    await tester.pump(const Duration(milliseconds: 300));

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
}
