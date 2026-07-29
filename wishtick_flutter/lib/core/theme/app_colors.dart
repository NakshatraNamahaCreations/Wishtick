import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Semantic colour tokens for Wishtick.
///
/// Widgets read these via `context.colors.<token>` — never [AppPalette], and
/// never a raw [Color]. Each token below declares its **light** and **dark**
/// value side by side so the two themes cannot drift apart: adding a token
/// forces you to answer "what is this in dark mode?" at the same moment.
@immutable
class WishtickColors extends ThemeExtension<WishtickColors> {
  const WishtickColors({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryDeep,
    required this.primaryMuted,
    required this.primarySubtle,
    required this.accent,
    required this.onAccent,
    required this.accentSubtle,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunken,
    required this.border,
    required this.overlay,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnDark,
    required this.success,
    required this.successSubtle,
    required this.danger,
    required this.onDanger,
    required this.dangerSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.info,
    required this.infoSubtle,
    required this.celebration,
    required this.celebrationSubtle,
    required this.navBackground,
    required this.navSelected,
    required this.navUnselected,
    required this.shadow,
  });

  final Brightness brightness;

  /// Brand plum. Primary buttons, active nav, selected chips.
  final Color primary;
  final Color onPrimary;
  final Color primaryDeep;
  final Color primaryMuted;

  /// Tinted plum background for pills, badges and selected states.
  final Color primarySubtle;

  /// Brand pink. Hearts, wishlist affordances, inline emphasis.
  final Color accent;
  final Color onAccent;
  final Color accentSubtle;

  /// Page background behind [surface] cards.
  final Color background;

  /// Default card / sheet fill.
  final Color surface;

  /// Secondary card fill (lavender in light, raised grey in dark).
  final Color surfaceAlt;

  /// Recessed areas — search fields, image placeholders.
  final Color surfaceSunken;

  final Color border;

  /// Scrim behind modals and bottom sheets.
  final Color overlay;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Text drawn on top of [primary]/photographic surfaces in both themes.
  final Color textOnDark;

  final Color success;
  final Color successSubtle;
  final Color danger;

  /// Text/icons drawn on top of [danger] — inverts between themes because
  /// [danger] is a deep red in light mode and a light red in dark mode.
  final Color onDanger;
  final Color dangerSubtle;
  final Color warning;
  final Color warningSubtle;
  final Color info;
  final Color infoSubtle;

  /// Gold "celebration" treatment used by group-gift and event cards.
  final Color celebration;
  final Color celebrationSubtle;

  final Color navBackground;
  final Color navSelected;
  final Color navUnselected;

  /// Base colour for elevation shadows.
  final Color shadow;

  static const light = WishtickColors(
    brightness: Brightness.light,
    primary: AppPalette.plum,
    onPrimary: AppPalette.ivory,
    primaryDeep: AppPalette.plumDeep,
    primaryMuted: AppPalette.plumMuted,
    primarySubtle: AppPalette.plumPale,
    accent: AppPalette.pink,
    // Ink, not white: white on this pink is only 2.7:1, below AA. Ink is 6:1.
    onAccent: AppPalette.ink,
    accentSubtle: AppPalette.pinkPale,
    background: AppPalette.cream,
    surface: AppPalette.white,
    surfaceAlt: AppPalette.violetPale,
    surfaceSunken: AppPalette.ivoryDeep,
    border: AppPalette.border,
    overlay: AppPalette.scrim,
    textPrimary: AppPalette.ink,
    textSecondary: AppPalette.inkSoft,
    textMuted: AppPalette.textMuted,
    textOnDark: AppPalette.ivory,
    success: AppPalette.teal,
    successSubtle: AppPalette.tealSoft,
    danger: AppPalette.coral,
    onDanger: AppPalette.white,
    dangerSubtle: AppPalette.coralSoft,
    warning: AppPalette.amber,
    warningSubtle: AppPalette.amberSoft,
    info: AppPalette.blue,
    infoSubtle: AppPalette.bluePale,
    celebration: AppPalette.gold,
    celebrationSubtle: AppPalette.goldSoft,
    navBackground: AppPalette.white,
    navSelected: AppPalette.plum,
    navUnselected: AppPalette.textMuted,
    shadow: AppPalette.black,
  );

  /// Dark mapping.
  ///
  /// Plum is too dark to read as "primary" on a dark background, so [primary]
  /// steps up to the brighter plum while [primaryDeep] keeps the brand plum for
  /// fills that still need weight. Ivory/cream surfaces invert to the dark
  /// neutral ramp; pink and gold stay put because they already carry enough
  /// luminance.
  static const dark = WishtickColors(
    brightness: Brightness.dark,
    primary: AppPalette.plumBright,
    onPrimary: AppPalette.ivory,
    primaryDeep: AppPalette.plum,
    primaryMuted: AppPalette.plumSoft,
    primarySubtle: AppPalette.darkSurfaceAlt,
    accent: AppPalette.pink,
    // [accent] is the same pink in both themes, so its foreground matches too.
    onAccent: AppPalette.navyDeep,
    accentSubtle: AppPalette.darkPinkSubtle,
    background: AppPalette.darkBackground,
    surface: AppPalette.darkSurface,
    surfaceAlt: AppPalette.darkSurfaceAlt,
    surfaceSunken: AppPalette.darkSurfaceSunken,
    border: AppPalette.darkBorder,
    overlay: AppPalette.darkScrim,
    textPrimary: AppPalette.darkTextPrimary,
    textSecondary: AppPalette.darkTextSecondary,
    textMuted: AppPalette.darkTextMuted,
    textOnDark: AppPalette.ivory,
    success: AppPalette.darkTeal,
    successSubtle: AppPalette.darkTealSubtle,
    danger: AppPalette.darkCoral,
    onDanger: AppPalette.navyDeep,
    dangerSubtle: AppPalette.darkCoralSubtle,
    warning: AppPalette.amber,
    warningSubtle: AppPalette.darkAmberSubtle,
    info: AppPalette.blueSoft,
    infoSubtle: AppPalette.darkBlueSubtle,
    celebration: AppPalette.goldSoft,
    celebrationSubtle: AppPalette.darkGoldSubtle,
    navBackground: AppPalette.darkSurface,
    navSelected: AppPalette.pink,
    navUnselected: AppPalette.darkTextMuted,
    shadow: AppPalette.black,
  );

  @override
  WishtickColors copyWith({
    Brightness? brightness,
    Color? primary,
    Color? onPrimary,
    Color? primaryDeep,
    Color? primaryMuted,
    Color? primarySubtle,
    Color? accent,
    Color? onAccent,
    Color? accentSubtle,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceSunken,
    Color? border,
    Color? overlay,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textOnDark,
    Color? success,
    Color? successSubtle,
    Color? danger,
    Color? onDanger,
    Color? dangerSubtle,
    Color? warning,
    Color? warningSubtle,
    Color? info,
    Color? infoSubtle,
    Color? celebration,
    Color? celebrationSubtle,
    Color? navBackground,
    Color? navSelected,
    Color? navUnselected,
    Color? shadow,
  }) {
    return WishtickColors(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      primarySubtle: primarySubtle ?? this.primarySubtle,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      border: border ?? this.border,
      overlay: overlay ?? this.overlay,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textOnDark: textOnDark ?? this.textOnDark,
      success: success ?? this.success,
      successSubtle: successSubtle ?? this.successSubtle,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerSubtle: dangerSubtle ?? this.dangerSubtle,
      warning: warning ?? this.warning,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      info: info ?? this.info,
      infoSubtle: infoSubtle ?? this.infoSubtle,
      celebration: celebration ?? this.celebration,
      celebrationSubtle: celebrationSubtle ?? this.celebrationSubtle,
      navBackground: navBackground ?? this.navBackground,
      navSelected: navSelected ?? this.navSelected,
      navUnselected: navUnselected ?? this.navUnselected,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  WishtickColors lerp(covariant WishtickColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return WishtickColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryDeep: c(primaryDeep, other.primaryDeep),
      primaryMuted: c(primaryMuted, other.primaryMuted),
      primarySubtle: c(primarySubtle, other.primarySubtle),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentSubtle: c(accentSubtle, other.accentSubtle),
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      border: c(border, other.border),
      overlay: c(overlay, other.overlay),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      textOnDark: c(textOnDark, other.textOnDark),
      success: c(success, other.success),
      successSubtle: c(successSubtle, other.successSubtle),
      danger: c(danger, other.danger),
      onDanger: c(onDanger, other.onDanger),
      dangerSubtle: c(dangerSubtle, other.dangerSubtle),
      warning: c(warning, other.warning),
      warningSubtle: c(warningSubtle, other.warningSubtle),
      info: c(info, other.info),
      infoSubtle: c(infoSubtle, other.infoSubtle),
      celebration: c(celebration, other.celebration),
      celebrationSubtle: c(celebrationSubtle, other.celebrationSubtle),
      navBackground: c(navBackground, other.navBackground),
      navSelected: c(navSelected, other.navSelected),
      navUnselected: c(navUnselected, other.navUnselected),
      shadow: c(shadow, other.shadow),
    );
  }
}
