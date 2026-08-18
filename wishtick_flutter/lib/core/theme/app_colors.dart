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
    required this.chipFill,
    required this.payment,
    required this.paymentSubtle,
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
    required this.onSuccessSubtle,
    required this.danger,
    required this.onDanger,
    required this.dangerSubtle,
    required this.onDangerSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.onWarningSubtle,
    required this.info,
    required this.infoSubtle,
    required this.celebration,
    required this.celebrationSubtle,
    required this.noteSubtle,
    required this.onNoteSubtle,
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

  /// Fill of a value chip — the suggested-contribution amounts on `299:1658`.
  /// Sits on the page rather than on a card, so it is deeper than
  /// [optionFill], which would vanish against beige.
  final Color chipFill;

  /// The money-handling accent: UPI panels, "collected in your account",
  /// settle-up amounts. Text and icons.
  ///
  /// Separate from [success] on purpose — a UPI panel is not a success state,
  /// and reusing the tick colour for "where the money goes" makes an unpaid
  /// settlement look settled.
  final Color payment;

  /// Fill behind [payment].
  final Color paymentSubtle;

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

  /// Text drawn on [successSubtle]. Its own token for the same reason
  /// [onDanger] is: the fill is a near-white tint in light mode and a deep one
  /// in dark, so the ink has to invert with it rather than follow [success].
  final Color onSuccessSubtle;

  final Color danger;

  /// Text/icons drawn on top of [danger] — inverts between themes because
  /// [danger] is a deep red in light mode and a light red in dark mode.
  final Color onDanger;
  final Color dangerSubtle;

  /// Text drawn on [dangerSubtle]. See [onSuccessSubtle].
  final Color onDangerSubtle;
  final Color warning;
  final Color warningSubtle;

  /// Text drawn on [warningSubtle]. See [onSuccessSubtle].
  final Color onWarningSubtle;

  final Color info;
  final Color infoSubtle;

  /// Gold "celebration" treatment used by group-gift and event cards.
  final Color celebration;
  final Color celebrationSubtle;

  /// Fill for the onboarding "note" callout — a translucent wash, unlike the
  /// other `*Subtle` tokens which are solid tints. See
  /// [AppPalette.noteFillSubtle].
  final Color noteSubtle;

  /// Text/icon drawn on [noteSubtle].
  final Color onNoteSubtle;

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
    chipFill: AppPalette.lavenderChip,
    payment: AppPalette.payTeal,
    paymentSubtle: AppPalette.payMint,
    surfaceSunken: AppPalette.ivory,
    border: AppPalette.border,
    outline: AppPalette.lilacLine,
    overlay: AppPalette.scrim,
    textPrimary: AppPalette.ink,
    textSecondary: AppPalette.inkSoft,
    textMuted: AppPalette.textMuted,
    textOnDark: AppPalette.ivory,
    success: AppPalette.teal,
    successSubtle: AppPalette.rsvpYesFill,
    onSuccessSubtle: AppPalette.rsvpYesInk,
    // The alarm red from the screens, not the brand coral — see AppPalette.
    danger: AppPalette.redAlert,
    onDanger: AppPalette.white,
    dangerSubtle: AppPalette.redAlertSubtle,
    onDangerSubtle: AppPalette.redAlertInk,
    warning: AppPalette.amber,
    warningSubtle: AppPalette.rsvpMaybeFill,
    onWarningSubtle: AppPalette.rsvpMaybeInk,
    info: AppPalette.blue,
    infoSubtle: AppPalette.bluePale,
    celebration: AppPalette.goldDeep,
    celebrationSubtle: AppPalette.goldSoft,
    noteSubtle: AppPalette.noteFillSubtle,
    onNoteSubtle: AppPalette.noteInk,
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
    chipFill: AppPalette.darkSurfaceAlt,
    payment: AppPalette.darkPayTeal,
    paymentSubtle: AppPalette.darkPaySubtle,
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
    onSuccessSubtle: AppPalette.darkTeal,
    danger: AppPalette.darkCoral,
    onDanger: AppPalette.navyDeep,
    dangerSubtle: AppPalette.darkCoralSubtle,
    onDangerSubtle: AppPalette.darkCoral,
    warning: AppPalette.amber,
    warningSubtle: AppPalette.darkAmberSubtle,
    onWarningSubtle: AppPalette.amber,
    info: AppPalette.blueSoft,
    infoSubtle: AppPalette.darkBlueSubtle,
    celebration: AppPalette.goldSoft,
    celebrationSubtle: AppPalette.darkGoldSubtle,
    noteSubtle: AppPalette.darkGoldSubtle,
    onNoteSubtle: AppPalette.amberSoft,
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
    Color? chipFill,
    Color? payment,
    Color? paymentSubtle,
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
    Color? onSuccessSubtle,
    Color? danger,
    Color? onDanger,
    Color? dangerSubtle,
    Color? onDangerSubtle,
    Color? warning,
    Color? warningSubtle,
    Color? onWarningSubtle,
    Color? info,
    Color? infoSubtle,
    Color? celebration,
    Color? celebrationSubtle,
    Color? noteSubtle,
    Color? onNoteSubtle,
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
      chipFill: chipFill ?? this.chipFill,
      payment: payment ?? this.payment,
      paymentSubtle: paymentSubtle ?? this.paymentSubtle,
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
      onSuccessSubtle: onSuccessSubtle ?? this.onSuccessSubtle,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerSubtle: dangerSubtle ?? this.dangerSubtle,
      onDangerSubtle: onDangerSubtle ?? this.onDangerSubtle,
      warning: warning ?? this.warning,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      onWarningSubtle: onWarningSubtle ?? this.onWarningSubtle,
      info: info ?? this.info,
      infoSubtle: infoSubtle ?? this.infoSubtle,
      celebration: celebration ?? this.celebration,
      celebrationSubtle: celebrationSubtle ?? this.celebrationSubtle,
      noteSubtle: noteSubtle ?? this.noteSubtle,
      onNoteSubtle: onNoteSubtle ?? this.onNoteSubtle,
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
      chipFill: c(chipFill, other.chipFill),
      payment: c(payment, other.payment),
      paymentSubtle: c(paymentSubtle, other.paymentSubtle),
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
      onSuccessSubtle: c(onSuccessSubtle, other.onSuccessSubtle),
      danger: c(danger, other.danger),
      onDanger: c(onDanger, other.onDanger),
      dangerSubtle: c(dangerSubtle, other.dangerSubtle),
      onDangerSubtle: c(onDangerSubtle, other.onDangerSubtle),
      warning: c(warning, other.warning),
      warningSubtle: c(warningSubtle, other.warningSubtle),
      onWarningSubtle: c(onWarningSubtle, other.onWarningSubtle),
      info: c(info, other.info),
      infoSubtle: c(infoSubtle, other.infoSubtle),
      celebration: c(celebration, other.celebration),
      celebrationSubtle: c(celebrationSubtle, other.celebrationSubtle),
      noteSubtle: c(noteSubtle, other.noteSubtle),
      onNoteSubtle: c(onNoteSubtle, other.onNoteSubtle),
      navBackground: c(navBackground, other.navBackground),
      navSelected: c(navSelected, other.navSelected),
      navUnselected: c(navUnselected, other.navUnselected),
      shadow: c(shadow, other.shadow),
    );
  }
}
