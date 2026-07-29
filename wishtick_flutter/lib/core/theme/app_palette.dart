import 'package:flutter/material.dart';

/// The Wishtick raw colour palette.
///
/// **This is the only file in the app that may contain colour literals.**
/// Widgets must never reference [AppPalette] directly — they read semantic
/// tokens from `context.colors` (see `app_colors.dart`). Rebranding the app
/// therefore means editing this one file.
///
/// Swatch names mirror the "Color System" page of the Figma file
/// (`8OShdlUS8kUWEE6j5DQ8GP`, node `0:1`) so design and code stay in step.
///
/// Values were derived from the rendered Figma frames. The Figma MCP variable
/// export was unavailable (Starter-plan tool-call limit), so before shipping
/// Sprint 0 these should be reconciled against the Color System page via
/// `get_variable_defs`. Swatches marked `[derived]` were interpolated because
/// they do not appear in the screens exported so far.
abstract final class AppPalette {
  // --- Plum (brand primary) -------------------------------------------------
  static const plum = Color(0xFF3F0E4C);
  static const plumDeep = Color(0xFF23074A);
  static const plumBright = Color(0xFF5B1A6E);
  static const plumSoft = Color(0xFF7B3A8F);
  static const plumMuted = Color(0xFF522651);
  static const plumPale = Color(0xFFF3F0F4);

  // --- Pink (accent) --------------------------------------------------------
  static const pink = Color(0xFFFF6994);
  static const pinkSoft = Color(0xFFFF93B0);
  static const pinkPale = Color(0xFFFFEAF0); // [derived]

  // --- Ivory / cream (light surfaces) ---------------------------------------
  static const ivory = Color(0xFFFFFCFA);
  static const ivoryDeep = Color(0xFFFFFBF7);
  static const cream = Color(0xFFF5ECE4);

  // --- Gold -----------------------------------------------------------------
  static const gold = Color(0xFFC79953);
  static const goldSoft = Color(0xFFEFD5B2);

  // --- Coral (danger) -------------------------------------------------------
  static const coral = Color(0xFFD51111);
  static const coralSoft = Color(0xFFFFD8D5); // [derived]
  static const roseSoft = Color(0xFFF3E7EA); // [derived]

  // --- Teal (success) -------------------------------------------------------
  static const teal = Color(0xFF2E9253);
  static const tealSoft = Color(0xFFD7EFDF); // [derived]

  // --- Navy -----------------------------------------------------------------
  static const navy = Color(0xFF1E1B3A);
  static const navyDeep = Color(0xFF120F26); // [derived]

  // --- Violet ---------------------------------------------------------------
  static const violet = Color(0xFFA02DC1);
  static const violetSoft = Color(0xFFB7ADF2);
  static const violetPale = Color(0xFFFAF9FE);

  // --- Amber (warning) ------------------------------------------------------
  static const amber = Color(0xFFE8A33D); // [derived]
  static const amberSoft = Color(0xFFF7E4C3);

  // --- Blue (informational surfaces, e.g. event cards) ----------------------
  static const blue = Color(0xFF4A90D9); // [derived]
  static const blueSoft = Color(0xFFBADEFC);
  static const bluePale = Color(0xFFE3F1FE);

  // --- Ink / text -----------------------------------------------------------
  static const ink = Color(0xFF1E1B3A);
  static const inkSoft = Color(0xFF4A4463);
  static const textMuted = Color(0xFF8A82A1);
  static const textFaint = Color(0xFFB4AEC4); // [derived]

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
  // either too dark to read (teal, coral) or too saturated against the dark
  // ramp. Their `*Container` partners are near-black tints of the same hue.
  static const darkPinkSubtle = Color(0xFF3A1F2C);
  static const darkTeal = Color(0xFF4CB878);
  static const darkTealSubtle = Color(0xFF1B3A29);
  static const darkCoral = Color(0xFFFF6B6B);
  static const darkCoralSubtle = Color(0xFF3D1D1D);
  static const darkAmberSubtle = Color(0xFF3D2E18);
  static const darkBlueSubtle = Color(0xFF1B2B3D);
  static const darkGoldSubtle = Color(0xFF3A2E1E);
}
