import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/core/theme/app_colors.dart';
import 'package:wishtick_flutter/core/theme/app_dimens.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/auth/data/auth_repository.dart';
import 'package:wishtick_flutter/features/auth/presentation/session_controller.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/splash/presentation/splash_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/onboarding_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSplash(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          onboardingRepositoryProvider.overrideWithValue(
            FakeOnboardingRepository(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SplashScreen()),
      ),
    );
  }

  testWidgets('shows the splash GIF full-bleed', (tester) async {
    await pumpSplash(tester);

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, SplashScreen.asset);
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('draws light status-bar icons over the dark backdrop', (
    tester,
  ) async {
    await pumpSplash(tester);

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(region.value, SystemUiOverlayStyle.light);
  });

  testWidgets(
    'the page behind the GIF matches its darkest frame, not the app theme',
    (tester) async {
      await pumpSplash(tester);

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        WishtickColors.light.splashBackground,
      );
    },
  );

  test('holds for 4.5s, a beat short of the full 5s GIF', () {
    expect(AppDurations.splash, const Duration(milliseconds: 4500));
  });

  testWidgets('holds for the full 4.5s before resolving the session', (
    tester,
  ) async {
    await pumpSplash(tester);

    // Short of AppDurations.splash — the session must still be unresolved.
    await tester.pump(AppDurations.splash - const Duration(milliseconds: 1));
    final context = tester.element(find.byType(SplashScreen));
    expect(
      ProviderScope.containerOf(context).read(sessionProvider).status,
      SessionStatus.unknown,
    );

    // Crossing the mark fires the timer, which resolves the session.
    await tester.pump(const Duration(milliseconds: 2));
    expect(
      ProviderScope.containerOf(context).read(sessionProvider).status,
      isNot(SessionStatus.unknown),
    );
  });
}
