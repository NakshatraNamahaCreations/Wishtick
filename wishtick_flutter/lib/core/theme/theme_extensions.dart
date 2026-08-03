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
}
