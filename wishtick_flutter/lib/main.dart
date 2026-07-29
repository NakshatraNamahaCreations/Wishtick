import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/session_controller.dart';

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
      ],
      child: const WishtickApp(),
    ),
  );
}
