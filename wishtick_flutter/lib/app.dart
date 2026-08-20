import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/dev/dev_mode.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/dismiss_keyboard_on_tap.dart';

class WishtickApp extends ConsumerWidget {
  const WishtickApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Wishtick',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: AppTheme.light,
      // While dark mode is off, `darkTheme` is withheld and the mode is pinned:
      // together they stop a device set to dark from flipping the app anyway,
      // which `themeMode` alone would not.
      darkTheme: kDarkModeEnabled ? AppTheme.dark : null,
      themeMode: kDarkModeEnabled
          ? ref.watch(themeModeProvider)
          : ThemeMode.light,
      builder: (context, child) {
        final content = DismissKeyboardOnTap(
          child: child ?? const SizedBox.shrink(),
        );
        // An unmissable corner ribbon while the app is running on fakes, so a
        // screenshot or bug report can never be mistaken for the real
        // backend.
        if (!DevMode.fakeBackend) return content;
        return Banner(
          message: 'FAKE API',
          location: BannerLocation.topEnd,
          child: content,
        );
      },
    );
  }
}
