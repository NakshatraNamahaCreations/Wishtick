import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_gradients.dart';

/// Ergonomic access to the Wishtick design tokens.
///
/// ```dart
/// Container(color: context.colors.surface)
/// Text('Hi', style: context.text.titleLarge)
/// ```
extension WishtickThemeContext on BuildContext {
  /// Semantic colour tokens for the active theme.
  ///
  /// Falls back to the light tokens if the extension is missing, which only
  /// happens inside a bare [MaterialApp] in tests.
  WishtickColors get colors =>
      Theme.of(this).extension<WishtickColors>() ?? WishtickColors.light;

  /// Gradient tokens for the active theme.
  WishtickGradients get gradients =>
      Theme.of(this).extension<WishtickGradients>() ?? WishtickGradients.light;

  TextTheme get text => Theme.of(this).textTheme;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// The colour for a large brand headline drawn straight on the page.
  ///
  /// Light mode uses the plum the mocks show, which clears 10:1 on the beige
  /// page. Dark mode cannot: `colors.primary` there is #5B1A6E, measuring
  /// **1.61:1** against the #17101B background — under the 3:1 floor for large
  /// text — so it steps to [WishtickColors.brandMark], the token whose job is
  /// to stay legible in both themes (5.88:1 here).
  ///
  /// A workaround, not a fix: the same 1.61:1 applies to *every* headline
  /// drawn in `colors.primary` on a dark page, which is a palette decision
  /// rather than a per-screen one.
  Color get headlineBrandColor =>
      isDarkMode ? colors.brandMark : colors.primary;
}
