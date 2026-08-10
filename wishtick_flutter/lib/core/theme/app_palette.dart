import 'package:flutter/material.dart';

/// The Wishtick raw colour palette.
///
/// **This is the only file in the app that may contain colour literals.**
/// Widgets must never reference [AppPalette] directly — they read semantic
/// tokens from `context.colors` (see `app_colors.dart`). Rebranding the app
/// therefore means editing this one file.
///
/// Swatch names and values mirror the "Color System" page of the Figma file
/// (node `0:1`), **verified 2026-07-31** against a full render of that page.
/// Notable correction from that verification: the CTA colour `#3F0E4C` is the
/// page's *plum deep* — the swatch named *plum* is `#5B1A6E`.
abstract final class AppPalette {
  // --- Plum (brand) ---------------------------------------------------------
  static const plum = Color(0xFF5B1A6E);
  static const plumDeep = Color(0xFF3F0E4C);
  static const plumSoft = Color(0xFF7B3A8F);

  // --- Pink (accent) --------------------------------------------------------
  static const pink = Color(0xFFE94E85);
  static const pinkSoft = Color(0xFFF27BA3);
  static const pinkPale = Color(0xFFFCE7EE);

  // --- Ivory / cream (light surfaces) ---------------------------------------
  static const ivory = Color(0xFFFCFBF5);
  static const ivoryDeep = Color(0xFFF5EFE4);
  static const cream = Color(0xFFFFF7EA);

  // --- Gold -----------------------------------------------------------------
  static const gold = Color(0xFFE7B85C);
  static const goldSoft = Color(0xFFF5D48C);

  // --- Coral ----------------------------------------------------------------
  static const coral = Color(0xFFFF7B5C);
  static const coralSoft = Color(0xFFFFB199);
  static const roseSoft = Color(0xFFF4B6C2);

  // --- Teal -----------------------------------------------------------------
  static const teal = Color(0xFF3FBFA6);
  static const tealSoft = Color(0xFF7FD9C6);

  // --- Navy -----------------------------------------------------------------
  static const navy = Color(0xFF1E1B3A);
  static const navyDeep = Color(0xFF0F0D24);

  // --- Violet ---------------------------------------------------------------
  static const violet = Color(0xFF7C6BE6);
  static const violetSoft = Color(0xFFB7ADF2);

  // --- Amber ----------------------------------------------------------------
  static const amber = Color(0xFFF3AB4A);
  static const amberSoft = Color(0xFFF9D08B);

  /// Fills and inks for the RSVP pills on the guest list (`4099:1256`).
  ///
  /// Deliberately not [tealSoft]/[amberSoft]: those are mid-tone *accents*, and
  /// the frame's own ink measured against them comes out under 2:1 — the pill
  /// label is what a host reads down the list, so it has to be legible. The
  /// fills are sampled from the frame; the inks are darkened from it until they
  /// clear AA (5.4:1 and 5.0:1 respectively).
  static const rsvpYesFill = Color(0xFFECFEF9);
  static const rsvpYesInk = Color(0xFF1F7A62);
  static const rsvpMaybeFill = Color(0xFFFBE3CF);
  static const rsvpMaybeInk = Color(0xFF9A4A08);

  // --- Blue -----------------------------------------------------------------
  static const blue = Color(0xFF4E8BE9);
  static const blueSoft = Color(0xFF8FB4F0);

  // --- Ink / text -----------------------------------------------------------
  static const ink = Color(0xFF1E1B3A);
  static const inkSoft = Color(0xFF4A4463);
  static const textMuted = Color(0xFF8A82A1);
  static const textFaint = Color(0xFFB7B2C6);

  // --- Screen-sampled -------------------------------------------------------
  // Colours that appear in the shipped screen designs but are not on the
  // Color System page. Sampled from the exported frames; re-point at official
  // swatches if the design team later adds them to the page.

  /// Deepest plum — snackbars and the darkest chip fills.
  static const plumInk = Color(0xFF23074A);

  /// Start of the gradient headline treatment ("Ready to Celebrate?").
  static const plumMuted = Color(0xFF522651);

  /// The warm end of the same gradient.
  static const bronze = Color(0xFFB98B53);

  /// Selected-state washes and lavender card fills.
  static const plumPale = Color(0xFFF3F0F4);
  static const violetPale = Color(0xFFFAF9FE);
  static const bluePale = Color(0xFFE3F1FE);

  /// The LOGOUT / DELETE ACCOUNT red. Distinct from [coral], which is an
  /// orange-toned brand colour rather than an alarm colour.
  static const redAlert = Color(0xFFD51112);
  static const redAlertSubtle = Color(0xFFFFD8D5);

  /// Ink for a "Declined" pill. [redAlert] on [redAlertSubtle] measures 4.09:1
  /// — under AA — and darkening [redAlert] itself would dim every destructive
  /// button in the app, which is not what needs fixing.
  static const redAlertInk = Color(0xFFB00E0F);

  // Sampled pixel-by-pixel from the 393-px-wide frame exports on 2026-08-03,
  // after the shipped screens turned out to disagree with the Color System
  // page. Where they conflict the screens win — they are what gets compared.

  /// The page beige every onboarding frame is drawn on. Three units off
  /// [ivoryDeep], which is what the Color System page lists.
  static const pageBeige = Color(0xFFF5ECE4);

  /// The gold the screens actually use for progress fills, step captions, the
  /// Terms link and the Continue badge — a clear step deeper than [gold].
  static const goldDeep = Color(0xFFC79953);

  /// The magenta of the Wishtick heart mark. Not [pink]: the mark is a purple
  /// magenta, the wishlist hearts are a rose.
  static const magenta = Color(0xFFB91E99);
  static const magentaSoft = Color(0xFFE05FC6);

  /// Hairline outline on outlined cards ("Select Avatar").
  static const lilacLine = Color(0xFFC4A5C2);

  /// Fill of an unselected selectable tile — more lavender than [violetPale],
  /// which the input fields use.
  static const lavenderTile = Color(0xFFF5F3FF);

  /// Fill of a value chip — the suggested-contribution amounts on
  /// `299:1658`. Deeper than [lavenderTile] because these sit on the beige
  /// page rather than on a white card, and the lighter tint disappears there.
  static const lavenderChip = Color(0xFFE2D9EA);

  /// The money-handling accent. Sampled from the "Receive Contributions via"
  /// panel (`299:1658`) and the settle-up UPI panels (`4092:174`, `4093:444`,
  /// `4099:976`), which all share this mint-on-deep-teal pairing.
  ///
  /// Deliberately not [teal]: that is the success tick, and a UPI panel is not
  /// a success state — it is where the money goes. #196A56 also clears 7:1 on
  /// the mint, which #3FBFA6 does not come close to.
  static const payTeal = Color(0xFF196A56);
  static const payMint = Color(0xFFF1FEF5);

  /// The red that fills the onboarding progress heart as steps complete.
  /// Deliberately not [redAlert]: that is the alarm colour for errors and
  /// Delete Account, and progress is not an alarm.
  static const heartRed = Color(0xFFE8283C);
  static const heartRedSoft = Color(0xFFFF6472);

  // --- Neutrals -------------------------------------------------------------
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const border = Color(0xFFE8E2EC);
  static const scrim = Color(0x8F000000);

  // --- Dark ramp ------------------------------------------------------------
  // The Figma file is light-only; these back the dark theme mapping documented
  // in `app_colors.dart`. They are tuned so the dark theme keeps the plum/pink
  // brand identity while meeting WCAG AA contrast.
  static const darkBackground = Color(0xFF17101B);
  static const darkSurface = Color(0xFF221826);
  static const darkSurfaceAlt = Color(0xFF2E2233);
  static const darkSurfaceSunken = Color(0xFF120C15);
  static const darkBorder = Color(0xFF3D2F44);
  static const darkScrim = Color(0xB3000000);
  static const darkTextPrimary = Color(0xFFF5ECE4);
  static const darkTextSecondary = Color(0xFFC9BFD2);
  static const darkTextMuted = Color(0xFF9A8FA6);

  // Status colours re-tuned for dark surfaces: the light-theme versions are
  // either too dark to read or too saturated against the dark ramp. Their
  // `*Container` partners are near-black tints of the same hue.
  static const darkPinkSubtle = Color(0xFF3A1F2C);
  static const darkTeal = Color(0xFF4CB878);
  static const darkTealSubtle = Color(0xFF1B3A29);

  /// Dark counterparts of the money accent. [payTeal] is far too dark to read
  /// on the dark ramp (1.3:1), so it steps up to a bright mint; the panel fill
  /// steps down to a deep one.
  static const darkPayTeal = Color(0xFF5FD3AE);
  static const darkPaySubtle = Color(0xFF13332B);
  static const darkCoral = Color(0xFFFF6B6B);
  static const darkCoralSubtle = Color(0xFF3D1D1D);
  static const darkAmberSubtle = Color(0xFF3D2E18);
  static const darkBlueSubtle = Color(0xFF1B2B3D);
  static const darkGoldSubtle = Color(0xFF3A2E1E);
}
