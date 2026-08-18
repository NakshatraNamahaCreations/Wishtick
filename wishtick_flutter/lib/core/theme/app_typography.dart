import 'package:flutter/material.dart';

/// Typography for Wishtick.
///
/// Two families, matching the Figma "Logo font / headings / body" spec:
///  * **Cormorant Garamond** — the wordmark and hero headings ("Make Every
///    Wish Count!", "Every wish locked with Love").
///  * **Montserrat** — all UI text.
///
/// Both are bundled as variable fonts under `assets/fonts` rather than fetched
/// at runtime, so first launch has no flash of fallback type and the app works
/// offline. Weights are selected through [FontVariation] on the `wght` axis —
/// [FontWeight] alone does not move a variable axis.
///
/// Colours are applied by [buildTextTheme] from the active semantic tokens, so
/// text automatically follows light/dark. Never set a colour on a style here.
abstract final class AppTypography {
  static const displayFamily = 'CormorantGaramond';
  static const bodyFamily = 'Montserrat';

  static TextStyle _style({
    required String family,
    required double size,
    required FontWeight weight,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
    );
  }

  static TextStyle _display(
    double size,
    FontWeight weight, {
    double? height,
    double? letterSpacing,
  }) => _style(
    family: displayFamily,
    size: size,
    weight: weight,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle _body(
    double size,
    FontWeight weight, {
    double? height,
    TextDecoration? decoration,
  }) => _style(
    family: bodyFamily,
    size: size,
    weight: weight,
    height: height,
    decoration: decoration,
  );

  /// The wordmark ("WISHTICK").
  static TextStyle get wordmark =>
      _display(26, FontWeight.w600, letterSpacing: 2);

  static TextStyle get displayLarge =>
      _display(40, FontWeight.w600, height: 1.2);
  static TextStyle get displayMedium =>
      _display(32, FontWeight.w600, height: 1.25);

  /// Screen titles ("Create Your Profile", "Select Your Avatar", "Verify…").
  ///
  /// 30, not 26: the exports measure 28px from cap top to descender bottom,
  /// and Cormorant Garamond's cap+descender at this weight is ~0.92em — 30
  /// lands the same ~28px it did under Playfair Display, whose ratio was
  /// nearly identical.
  static TextStyle get displaySmall =>
      _display(30, FontWeight.w600, height: 1.3);

  static TextStyle get headlineLarge => _body(24, FontWeight.w700, height: 1.3);
  static TextStyle get headlineMedium =>
      _body(20, FontWeight.w700, height: 1.3);
  static TextStyle get headlineSmall =>
      _body(18, FontWeight.w600, height: 1.35);

  static TextStyle get titleLarge => _body(16, FontWeight.w600, height: 1.4);
  static TextStyle get titleMedium => _body(15, FontWeight.w600, height: 1.4);
  static TextStyle get titleSmall => _body(14, FontWeight.w600, height: 1.4);

  static TextStyle get bodyLarge => _body(16, FontWeight.w400, height: 1.5);
  static TextStyle get bodyMedium => _body(14, FontWeight.w400, height: 1.5);
  static TextStyle get bodySmall => _body(12, FontWeight.w400, height: 1.45);

  static TextStyle get labelLarge => _body(16, FontWeight.w600, height: 1.2);
  static TextStyle get labelMedium => _body(13, FontWeight.w500, height: 1.2);
  static TextStyle get labelSmall => _body(11, FontWeight.w500, height: 1.2);

  /// Price / currency figures.
  static TextStyle get price => _body(16, FontWeight.w700, height: 1.3);

  static TextStyle get priceStruck => _body(
    13,
    FontWeight.w400,
    height: 1.3,
    decoration: TextDecoration.lineThrough,
  );

  static TextTheme buildTextTheme({
    required Color primary,
    required Color secondary,
  }) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: primary),
      displayMedium: displayMedium.copyWith(color: primary),
      displaySmall: displaySmall.copyWith(color: primary),
      headlineLarge: headlineLarge.copyWith(color: primary),
      headlineMedium: headlineMedium.copyWith(color: primary),
      headlineSmall: headlineSmall.copyWith(color: primary),
      titleLarge: titleLarge.copyWith(color: primary),
      titleMedium: titleMedium.copyWith(color: primary),
      titleSmall: titleSmall.copyWith(color: primary),
      bodyLarge: bodyLarge.copyWith(color: primary),
      bodyMedium: bodyMedium.copyWith(color: secondary),
      bodySmall: bodySmall.copyWith(color: secondary),
      labelLarge: labelLarge.copyWith(color: primary),
      labelMedium: labelMedium.copyWith(color: secondary),
      labelSmall: labelSmall.copyWith(color: secondary),
    );
  }
}
