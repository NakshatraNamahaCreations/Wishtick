import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/dev/dev_mode.dart';
import 'core/dev/dev_repositories.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/session_controller.dart';
import 'features/onboarding/data/onboarding_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolved before the first frame so the saved theme applies immediately —
  // otherwise the app renders one frame in the wrong brightness.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // A rejected refresh token must sign the user out, not just clear
        // storage — see session_controller.dart.
        sessionExpiryOverride,
        // Debug-only, opt-in: run the whole app against in-memory fakes. Both
        // repositories are swapped together — faking auth alone would sign the
        // user in and strand them on the first onboarding screen waiting out a
        // connect timeout. See core/dev/dev_mode.dart.
        if (DevMode.fakeBackend) ...[
          authRepositoryProvider.overrideWithValue(DevAuthRepository(prefs)),
          onboardingRepositoryProvider.overrideWithValue(
            DevOnboardingRepository(prefs),
          ),
        ],
      ],
      child: const WishtickApp(),
    ),
  );
}
