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

  // Onboarding — a 5-step wizard; "Create Your Profile" is step 1.
  static const onboarding = '/onboarding';
  static const onboardingAvatar = '/onboarding/avatar';
  static const onboardingInterests = '/onboarding/interests';
  static const onboardingColors = '/onboarding/colors';
  static const onboardingSizes = '/onboarding/sizes';
  static const onboardingDates = '/onboarding/dates';
  static const onboardingDone = '/onboarding/done';

  /// The per-category granular-interest screen (Figma `204:471` pattern).
  static String onboardingInterestDetail(String categoryKey) =>
      '/onboarding/interests/$categoryKey';

  // Tab shell
  static const home = '/home';
  static const wishlist = '/wishlist';
  static const memories = '/memories';
  static const profile = '/profile';

  // Wishlist (Sprint 3)
  static const wishlistCreate = '/wishlist/create';
  static String wishlistDetail(String id) => '/wishlist/$id';

  /// Root-level — reached from wherever a product is found (search, a
  /// resolved link), not tied to any one wishlist. Takes the product via
  /// `extra` (`NormalizedProduct` or `ResolvedUrlProduct`).
  static const productDetail = '/product';

  // Home (Sprint 4)
  static const deliveryLocation = '/delivery-location';

  /// A wishlist opened through its share link. Public — a link holder is not
  /// a participant.
  static String publicWishlist(String slug) => '/w/$slug';

  // Gifting (Sprint 5)

  /// An item on someone else's wishlist, with the Reserve / Gift Now / Group
  /// Gift actions. Separate from `wishlistDetail(...)/items/...`, which is the
  /// owner's own view of an item and offers edit and delete instead.
  static String giftItem(String wishlistId, String itemId) =>
      '/gift/$wishlistId/items/$itemId';

  /// Where to deliver it and what to say — the last step before the merchant
  /// hand-off (Figma `316:834`).
  static String giftDetails(String wishlistId, String itemId) =>
      '/gift/$wishlistId/items/$itemId/details';

  /// "Your Gift is confirmed!" (`299:1486`). Keyed by the gift rather than the
  /// order, because the order is minted by an event the client never sees —
  /// this screen looks it up.
  static String orderConfirmed(String giftId) => '/gifts/$giftId/confirmed';

  /// Track Order for a gift whose order id you do not have yet — which is
  /// every path that comes straight from a purchase.
  static String giftOrder(String giftId) => '/gifts/$giftId/order';

  /// Track Order. Reached from a confirmation screen or the gift list.
  static String order(String orderId) => '/orders/$orderId';

  /// "Gift Delivered!" (`299:1620`).
  static String orderDelivered(String orderId) => '/orders/$orderId/delivered';

  /// An event invite. Public and unauthenticated — the token is the
  /// authorization, and requiring a signup to answer an invitation is the
  /// fastest way to collect no RSVPs at all.
  static String invite(String token) => '/i/$token';

  // Create flow, launched from the centre nav button
  static const create = '/create';

  // Settings
  static const appearance = '/profile/appearance';

  /// Order of the four tab branches in the shell — the index the bottom nav
  /// reports maps through this list.
  static const tabBranches = [home, wishlist, memories, profile];
}
