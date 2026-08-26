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
    required this.header,
    required this.celebration,
    required this.curatedBanner,
    required this.eventMasthead,
  });

  /// The plum masthead: Home's header card (`51:11`), and the hero on the
  /// Terms and Privacy Policy screens.
  ///
  /// Deep plum at the status bar easing into the brand plum below it, so the
  /// wordmark and the icons keep their contrast where the ink is darkest.
  final LinearGradient header;

  /// Serif display headings that sweep plum → bronze left to right, as on the
  /// sign-in screen (Figma `17:329`).
  final LinearGradient headline;

  /// The plum → violet wash behind celebratory sheet headers.
  final LinearGradient celebration;

  /// The Discover "CURATED GIFTS FOR EVERY OCCASION" banner's diagonal wash
  /// (`280:131`) — its own wine-toned gradient, distinct from [celebration]
  /// (used elsewhere for a different plum → violet treatment).
  final LinearGradient curatedBanner;

  /// The three-stop plum wash behind "What are you celebrating?" (`257:733`),
  /// the WishMates mastheads (`4177:42`, `4177:77`, `4177:111`, `4177:179`)
  /// and the profile hero (`4177:217`, `4177:267`).
  ///
  /// Not [header]: that one is a two-stop violet-leaning ink → plum, and every
  /// frame above starts on a warm near-black the header never reaches. Sampling
  /// `4177:217` down its left edge lands on these three stops to the pixel —
  /// #1D041D at the top, #612260 at the midpoint, #522651 at the foot.
  final LinearGradient eventMasthead;

  static const light = WishtickGradients(
    headline: LinearGradient(colors: [AppPalette.plumMuted, AppPalette.bronze]),
    // The pair the light theme calls primaryDeep → primary.
    header: LinearGradient(
      colors: [AppPalette.plumInk, AppPalette.plumMuted],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    celebration: LinearGradient(
      colors: [AppPalette.plumDeep, AppPalette.violet],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    curatedBanner: LinearGradient(
      colors: [AppPalette.wine, AppPalette.wineInk],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    ),
    eventMasthead: _eventMasthead,
  );

  /// Both stops step up in luminance so the sweep stays legible on the dark
  /// ramp — the light gradient's plum end would disappear into it.
  static const dark = WishtickGradients(
    headline: LinearGradient(
      colors: [AppPalette.violetSoft, AppPalette.goldSoft],
    ),
    header: LinearGradient(
      colors: [AppPalette.plumDeep, AppPalette.plum],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    celebration: LinearGradient(
      colors: [AppPalette.plum, AppPalette.violet],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    curatedBanner: LinearGradient(
      colors: [AppPalette.wineSoft, AppPalette.wine],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    ),
    eventMasthead: _eventMasthead,
  );

  /// Shared by both themes rather than brightened for the dark ramp like the
  /// stops above: this wash is already near-black at its top, so a dark-mode
  /// variant would be lightening the one masthead that is meant to be darkest.
  static const _eventMasthead = LinearGradient(
    colors: [AppPalette.plumShadow, AppPalette.plumRich, AppPalette.plumMuted],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  WishtickGradients copyWith({
    LinearGradient? headline,
    LinearGradient? header,
    LinearGradient? celebration,
    LinearGradient? curatedBanner,
    LinearGradient? eventMasthead,
  }) {
    return WishtickGradients(
      headline: headline ?? this.headline,
      header: header ?? this.header,
      celebration: celebration ?? this.celebration,
      curatedBanner: curatedBanner ?? this.curatedBanner,
      eventMasthead: eventMasthead ?? this.eventMasthead,
    );
  }

  @override
  WishtickGradients lerp(covariant WishtickGradients? other, double t) {
    if (other == null) return this;
    return WishtickGradients(
      headline: LinearGradient.lerp(headline, other.headline, t)!,
      header: LinearGradient.lerp(header, other.header, t)!,
      celebration: LinearGradient.lerp(celebration, other.celebration, t)!,
      curatedBanner: LinearGradient.lerp(
        curatedBanner,
        other.curatedBanner,
        t,
      )!,
      eventMasthead: LinearGradient.lerp(
        eventMasthead,
        other.eventMasthead,
        t,
      )!,
    );
  }
}
