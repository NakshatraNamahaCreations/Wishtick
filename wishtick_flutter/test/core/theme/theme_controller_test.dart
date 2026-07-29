import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/core/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> containerWith(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ThemeModeController.decode', () {
    test('maps stored values back to a ThemeMode', () {
      expect(ThemeModeController.decode('light'), ThemeMode.light);
      expect(ThemeModeController.decode('dark'), ThemeMode.dark);
      expect(ThemeModeController.decode('system'), ThemeMode.system);
    });

    test('falls back to system for missing or unknown values', () {
      expect(ThemeModeController.decode(null), ThemeMode.system);
      expect(ThemeModeController.decode('sepia'), ThemeMode.system);
    });
  });

  test('defaults to following the device setting', () async {
    final container = await containerWith({});
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('restores the saved preference on launch', () async {
    final container = await containerWith({
      ThemeModeController.prefsKey: 'dark',
    });
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('setThemeMode updates state and persists it', () async {
    final container = await containerWith({});

    await container
        .read(themeModeProvider.notifier)
        .setThemeMode(ThemeMode.dark);

    expect(container.read(themeModeProvider), ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeModeController.prefsKey), 'dark');
  });
}
