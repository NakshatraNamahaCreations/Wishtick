/// Keys the dev fakes persist under, so a restart behaves like a real session
/// rather than resetting the app to a blank slate every launch.
///
/// Shared between `dev_repositories.dart` and `dev_home_repositories.dart` —
/// Home derives its upcoming-occasions rail from the very dates onboarding
/// saved, so both files read [dates].
abstract final class DevKeys {
  static const phone = 'wishtick.dev.phone';
  static const name = 'wishtick.dev.name';
  static const onboardingComplete = 'wishtick.dev.onboarding_complete';
  static const dates = 'wishtick.dev.dates';
  static const wishlists = 'wishtick.dev.wishlists';
  static const wishlistItems = 'wishtick.dev.wishlist_items';

  /// Versioned: bumping it re-seeds an install that predates a change to the
  /// seed data, which is the only way a device already carrying dev state ever
  /// sees a newly added fixture.
  static const wishlistSeeded = 'wishtick.dev.wishlist_seeded.v2';
  static const addresses = 'wishtick.dev.addresses';
  static const gifts = 'wishtick.dev.gifts';
  static const orders = 'wishtick.dev.orders';
  static const invites = 'wishtick.dev.invites';
}
