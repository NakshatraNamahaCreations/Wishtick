/// Spacing, radius and sizing scale for Wishtick.
///
/// As with colours, widgets must not hardcode numbers — use these tokens so a
/// density change is a one-file edit. Values follow the 4-pt grid the Figma
/// frames are laid out on.
abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 40.0;

  /// Horizontal padding of a standard screen body.
  static const screenH = 16.0;
}

abstract final class AppRadius {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;

  /// Bottom sheets and modal tops.
  static const sheet = 28.0;

  /// Fully rounded pills (buttons, chips).
  static const pill = 999.0;
}

abstract final class AppSizes {
  static const buttonHeight = 56.0;
  static const inputHeight = 56.0;
  static const chipHeight = 36.0;
  static const bottomNavHeight = 68.0;
  static const fabSize = 56.0;
  static const iconSm = 16.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;
  static const avatarSm = 32.0;
  static const avatarMd = 44.0;
  static const avatarLg = 96.0;

  /// Minimum touch target (accessibility floor).
  static const minTapTarget = 48.0;
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);

  /// How long the splash holds before routing (matches the Figma progress bar).
  static const splash = Duration(milliseconds: 2000);
}
