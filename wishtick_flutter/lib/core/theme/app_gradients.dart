import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Gradient tokens.
///
/// Part of the theme layer for the same reason colours are: a gradient painted
/// from ad-hoc values in a widget is a gradient that will not follow a rebrand
/// or a theme switch. Each token declares its light and dark form together.
@immutable
class WishtickGradients extends ThemeExtension<WishtickGradients> {
  const WishtickGradients({
    required this.headline,
    required this.celebration,
    required this.splash,
  });

  /// Serif display headings that sweep plum → bronze left to right, as on the
  /// sign-in screen (Figma `17:329`).
  final LinearGradient headline;

  /// The plum → violet wash behind celebratory sheet headers.
  final LinearGradient celebration;

  /// The splash backdrop (Figma `143:356`) — a vertical plum wash falling from
  /// [AppPalette.plumMuted] to near-black.
  ///
  /// **The one token that is identical in light and dark, on purpose.** The
  /// splash is a brand moment rather than a page: it is the first frame the
  /// user sees, the mark and wordmark are drawn *for* this backdrop, and the
  /// screen carries no content that a light surface would serve better. Both
  /// [light] and [dark] therefore point at the same [_splash] — this is not an
  /// oversight to be "fixed" by giving dark its own stops.
  final LinearGradient splash;

  /// Shared by both themes — see [splash].
  static const _splash = LinearGradient(
    colors: [AppPalette.plumMuted, AppPalette.plumNight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const light = WishtickGradients(
    headline: LinearGradient(colors: [AppPalette.plumMuted, AppPalette.bronze]),
    celebration: LinearGradient(
      colors: [AppPalette.plumDeep, AppPalette.violet],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    splash: _splash,
  );

  /// Both stops step up in luminance so the sweep stays legible on the dark
  /// ramp — the light gradient's plum end would disappear into it.
  static const dark = WishtickGradients(
    headline: LinearGradient(
      colors: [AppPalette.violetSoft, AppPalette.goldSoft],
    ),
    celebration: LinearGradient(
      colors: [AppPalette.plum, AppPalette.violet],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    splash: _splash,
  );

  @override
  WishtickGradients copyWith({
    LinearGradient? headline,
    LinearGradient? celebration,
    LinearGradient? splash,
  }) {
    return WishtickGradients(
      headline: headline ?? this.headline,
      celebration: celebration ?? this.celebration,
      splash: splash ?? this.splash,
    );
  }

  @override
  WishtickGradients lerp(covariant WishtickGradients? other, double t) {
    if (other == null) return this;
    return WishtickGradients(
      headline: LinearGradient.lerp(headline, other.headline, t)!,
      celebration: LinearGradient.lerp(celebration, other.celebration, t)!,
      splash: LinearGradient.lerp(splash, other.splash, t)!,
    );
  }
}
