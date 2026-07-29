import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides the [SharedPreferences] instance.
///
/// Overridden in `main()` with an instance resolved *before* `runApp`, so theme
/// preferences are readable synchronously and the app never renders one frame
/// in the wrong theme.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'sharedPreferencesProvider must be overridden in ProviderScope. '
    'See bootstrap() in main.dart.',
  );
});

/// Persisted light / dark / system preference, surfaced in Profile → Appearance.
class ThemeModeController extends Notifier<ThemeMode> {
  static const prefsKey = 'wishtick.theme_mode';

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return decode(prefs.getString(prefsKey));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(prefsKey, mode.name);
  }

  @visibleForTesting
  static ThemeMode decode(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
