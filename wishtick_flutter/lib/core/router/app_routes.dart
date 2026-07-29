/// Route paths and names, kept in one place so deep links and navigation calls
/// cannot drift apart.
abstract final class AppRoutes {
  // Bootstrap
  static const splash = '/';

  // Auth (Sprint 1)
  static const welcome = '/welcome';
  static const createAccount = '/welcome/create-account';
  static const mobileNumber = '/welcome/mobile';
  static const otp = '/welcome/otp';

  // Onboarding (Sprint 2)
  static const onboarding = '/onboarding';

  // Tab shell
  static const home = '/home';
  static const wishlist = '/wishlist';
  static const memories = '/memories';
  static const profile = '/profile';

  // Create flow, launched from the centre nav button
  static const create = '/create';

  // Settings
  static const appearance = '/profile/appearance';

  /// Order of the four tab branches in the shell — the index the bottom nav
  /// reports maps through this list.
  static const tabBranches = [home, wishlist, memories, profile];
}
