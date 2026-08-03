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
    required this.brandMark,
    required this.heartFill,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.optionFill,
    required this.surfaceSunken,
    required this.border,
    required this.outline,
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

  /// The Wishtick heart mark itself — the logo magenta, which is a colder,
  /// more purple pink than [accent]. Only the brand mark uses it.
  final Color brandMark;

  /// Fills the onboarding progress heart as steps complete. A true red, kept
  /// separate from [danger] so progress never borrows the alarm colour.
  final Color heartFill;

  /// Page background behind [surface] cards.
  ///
  /// ⚠️ **Not final** — the design team has not confirmed the app background.
  /// This token is the single seam for it: `AppTheme` feeds it into
  /// `ThemeData.scaffoldBackgroundColor` and screens inherit from the theme
  /// rather than setting their own, so changing the light/dark values below is
  /// the whole change. (Screens that are deliberately white — the auth flow —
  /// set [surface] explicitly and are unaffected.)
  final Color background;

  /// Default card / sheet fill.
  final Color surface;

  /// Secondary card fill (lavender in light, raised grey in dark). Input fills.
  final Color surfaceAlt;

  /// Fill of an *unselected* selectable tile — gender, and the option tiles
  /// that follow it. A touch more lavender than [surfaceAlt] so a grid of
  /// options reads as tappable rather than as a row of inputs. Selected tiles
  /// use [primary].
  final Color optionFill;

  /// Recessed areas — search fields, image placeholders.
  final Color surfaceSunken;

  final Color border;

  /// Hairline around an *outlined* card — one that is defined by its edge
  /// rather than by a fill (the "Select Avatar" card). A tinted lilac, so it
  /// reads as brand rather than as the neutral [border] used on inputs.
  final Color outline;

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
    // Sampled from the frame exports: the Continue pill and the selected
    // gender tile are both #522651. The Color System page calls #3F0E4C the
    // CTA colour, but the shipped screens do not use it — so [primaryDeep]
    // keeps it for the places that genuinely need more weight.
    primary: AppPalette.plumMuted,
    onPrimary: AppPalette.ivory,
    primaryDeep: AppPalette.plumInk,
    // A genuinely *muted* plum. It used to resolve to #522651 — the same
    // colour as [primary] — which drew de-emphasised brand content at full
    // strength. The exports use #7B3A8F for the camera badge and for the
    // content of unselected option tiles.
    primaryMuted: AppPalette.plumSoft,
    primarySubtle: AppPalette.plumPale,
    accent: AppPalette.pink,
    // Ink, not white: white on this pink falls below AA. Ink clears 4.5:1.
    onAccent: AppPalette.ink,
    accentSubtle: AppPalette.pinkPale,
    brandMark: AppPalette.magenta,
    heartFill: AppPalette.heartRed,
    background: AppPalette.pageBeige,
    surface: AppPalette.white,
    surfaceAlt: AppPalette.violetPale,
    optionFill: AppPalette.lavenderTile,
    surfaceSunken: AppPalette.ivory,
    border: AppPalette.border,
    outline: AppPalette.lilacLine,
    overlay: AppPalette.scrim,
    textPrimary: AppPalette.ink,
    textSecondary: AppPalette.inkSoft,
    textMuted: AppPalette.textMuted,
    textOnDark: AppPalette.ivory,
    success: AppPalette.teal,
    successSubtle: AppPalette.tealSoft,
    // The alarm red from the screens, not the brand coral — see AppPalette.
    danger: AppPalette.redAlert,
    onDanger: AppPalette.white,
    dangerSubtle: AppPalette.redAlertSubtle,
    warning: AppPalette.amber,
    warningSubtle: AppPalette.amberSoft,
    info: AppPalette.blue,
    infoSubtle: AppPalette.bluePale,
    celebration: AppPalette.goldDeep,
    celebrationSubtle: AppPalette.goldSoft,
    navBackground: AppPalette.white,
    navSelected: AppPalette.plumMuted,
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
    primary: AppPalette.plum,
    onPrimary: AppPalette.ivory,
    primaryDeep: AppPalette.plumDeep,
    primaryMuted: AppPalette.plumSoft,
    primarySubtle: AppPalette.darkSurfaceAlt,
    accent: AppPalette.pink,
    // [accent] is the same pink in both themes, so its foreground matches too.
    onAccent: AppPalette.navyDeep,
    accentSubtle: AppPalette.darkPinkSubtle,
    // The logo magenta is too dark to read against the dark ramp; the mark
    // steps up to its soft variant to keep the same identity.
    brandMark: AppPalette.magentaSoft,
    heartFill: AppPalette.heartRedSoft,
    background: AppPalette.darkBackground,
    surface: AppPalette.darkSurface,
    surfaceAlt: AppPalette.darkSurfaceAlt,
    // No separate lavender in dark — a raised grey already reads as tappable.
    optionFill: AppPalette.darkSurfaceAlt,
    surfaceSunken: AppPalette.darkSurfaceSunken,
    border: AppPalette.darkBorder,
    // No lilac tint survives on the dark ramp; the neutral border is the
    // strongest edge that still reads as a hairline.
    outline: AppPalette.darkBorder,
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
    Color? brandMark,
    Color? heartFill,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? optionFill,
    Color? surfaceSunken,
    Color? border,
    Color? outline,
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
      brandMark: brandMark ?? this.brandMark,
      heartFill: heartFill ?? this.heartFill,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      optionFill: optionFill ?? this.optionFill,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      border: border ?? this.border,
      outline: outline ?? this.outline,
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
      brandMark: c(brandMark, other.brandMark),
      heartFill: c(heartFill, other.heartFill),
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      optionFill: c(optionFill, other.optionFill),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      border: c(border, other.border),
      outline: c(outline, other.outline),
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
