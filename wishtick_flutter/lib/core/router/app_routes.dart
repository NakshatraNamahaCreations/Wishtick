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

  /// Who can open a wishlist, and the only place to invite anyone — a private
  /// list's share link admits nobody. Takes the wishlist via `extra`.
  static String wishlistAccess(String id) => '/wishlist/$id/access';

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

  // Group gifting (Sprint 6b)
  //
  // Creation is a four-step flow: the group gift exists from step 1, and the
  // summary and charges screens edit its bill before anyone is asked to pay.
  // Each step is its own route so backing out lands on the previous one rather
  // than dumping the host out of a half-configured group.

  /// "Create Group Gift" (`299:1658`) — step 1, still keyed by the item
  /// because no group gift exists yet.
  static String createGroupGift(String wishlistId, String itemId) =>
      '/gift/$wishlistId/items/$itemId/group';

  /// "Group Gift Summary" (`4007:801`, `4006:463`) — step 2.
  static String groupGiftSummary(String id) => '/group-gifts/$id/summary';

  /// "Add Another Gift" (`4007:720`) — the picker step 2 pushes.
  static String groupGiftAddItem(String id) => '/group-gifts/$id/summary/add';

  /// "Miscellaneous Charges" (`4007:568`) — step 3.
  static String groupGiftCharges(String id) => '/group-gifts/$id/charges';

  /// "Add a Charge" (`4007:628`).
  static String groupGiftAddCharge(String id) => '/group-gifts/$id/charges/add';

  /// "Group Gift Created" (`299:1735`) — step 4.
  static String groupGiftCreated(String id) => '/group-gifts/$id/created';

  /// "Thank You!" (`316:298`) — shown after a pledge, and the only place the
  /// host's UPI ID appears.
  static String groupGiftContributed(String id) =>
      '/group-gifts/$id/contributed';

  /// "Group Gift Details" (`316:166`) — the live group everyone else sees.
  /// Where a "chip in with us" notification lands. No id in the path: the
  /// screen is the whole list of unanswered invitations, and the one that was
  /// tapped is in it.
  static const groupGiftInvites = '/group-gifts/invites';

  /// One invitation, with the gift behind it and the answer at the bottom.
  static String groupGiftInvite(String inviteId) =>
      '/group-gifts/invites/$inviteId';

  static String groupGift(String id) => '/group-gifts/$id';

  /// The participant list (`316:536`).
  static String groupGiftParticipants(String id) =>
      '/group-gifts/$id/participants';

  /// "Group Chat" (`316:640`). Takes the chat id as `extra` — a group gift
  /// carries its own `chatId`, so there is nothing to look up.
  static String groupGiftChat(String id) => '/group-gifts/$id/chat';

  /// "Thank You from …" (`2219:603`).
  static String groupGiftThankYou(String id) => '/group-gifts/$id/thank-you';

  /// The settle-up ledger — both directions (`4092:174`, `4093:444`).
  static String groupGiftSettle(String id) => '/group-gifts/$id/settle';

  // Events, host side (Sprint 7). Creation is a wizard held in one controller,
  // so each step is a sibling route rather than a nested one — backing out of
  // step 2 returns to step 1 with what was typed still there.

  /// "What are you celebrating?" (`257:733`) — step 1.
  static const createEvent = '/events/create';

  /// "Tell us about your event" (`257:755`) — step 2.
  static const createEventDetails = '/events/create/details';

  /// "Choose a Template" (`263:900`), "Upload Invitation" (`2248:70`) and
  /// "Preview Your Invite" (`263:1014`) for the event being created.
  ///
  /// No id in these, because there is no event yet: the whole wizard,
  /// invitation included, lives in the create controller until the preview's
  /// button is pressed. That press is what creates the event, and it lands on
  /// [eventShare] — the first path with an id in it.
  static const createEventInvite = '/events/create/invite';
  static const createEventInviteUpload = '/events/create/invite/upload';
  static const createEventInvitePreview = '/events/create/invite/preview';

  /// The host's own view of one event, from "My Events".
  static String eventDetail(String id) => '/events/$id';

  /// "Choose a Template" (`263:900`) for an event that already exists —
  /// changing the design from the event page.
  static String eventInviteTemplates(String id) => '/events/$id/invite';

  /// "Upload Invitation" (`2248:70`) — the other answer to the method sheet.
  static String eventInviteUpload(String id) => '/events/$id/invite/upload';

  /// "Preview Your Invite" (`263:1014`).
  static String eventInvitePreview(String id) => '/events/$id/invite/preview';

  /// "Share Your Invite" — where both invitation flows end. Nested under
  /// [eventDetail] so backing out of it lands on the event, not on a wizard
  /// step that no longer applies.
  static String eventShare(String id) => '/events/$id/share';

  /// The guest list (`4099:1256`).
  static String eventGuests(String id) => '/events/$id/guests';

  /// One guest (`4096:162`).
  static String eventGuest(String id, String inviteId) =>
      '/events/$id/guests/$inviteId';

  // Memories (Sprint 8). Creation is a two-step wizard held in one controller,
  // so the steps are siblings — backing out of step 2 returns to step 1 with
  // what was typed still there.

  /// "Create Memory" (`4104:1539`) — step 1.
  static const createMemory = '/memories/create';

  /// "How would you like to add the wish?" — step 2, where the host picks how
  /// to record their own first wish.
  static const createMemoryWishKind = '/memories/create/wish';

  /// Composing that wish, and previewing it — the two screens between picking
  /// a kind and sealing the memory.
  static const createMemoryWishCompose = '/memories/create/wish/compose';
  static const createMemoryWishPreview = '/memories/create/wish/preview';

  /// "When should this Memory Unlock?" (`2198:73`) — the last step.
  static const createMemoryUnlock = '/memories/create/unlock';

  /// One capsule — sealed, or its story once open.
  static String memory(String id) => '/memories/$id';

  /// "How would you like to add the wish?" for a capsule that already exists.
  static String memoryWishKind(String id) => '/memories/$id/wishes/kind';

  /// The viewer's own wishes, readable while the capsule is still sealed.
  static String memoryMyWishes(String id) => '/memories/$id/wishes/mine';

  /// The add-a-wish flow (`2073:55`, `2078:233`, `2074:129`, audio).
  static String memoryAddWish(String id) => '/memories/$id/wishes/add';

  /// The full experience (`2078:357`) — a story, one wish per segment.
  static String memoryExperience(String id) => '/memories/$id/experience';

  /// A memory's contribute link. Public — someone with no account may still
  /// add a wish, which is how a capsule fills up.
  static String memoryInvite(String slug) => '/m/$slug';

  /// A public event's open invitation — one link for everybody, so whoever
  /// opens it is identified by signing in rather than by the link. Resolves
  /// itself into [invite] once the join succeeds.
  static String publicEvent(String slug) => '/e/$slug';

  /// An event invite. Public and unauthenticated — the token is the
  /// authorization, and requiring a signup to answer an invitation is the
  /// fastest way to collect no RSVPs at all.
  static String invite(String token) => '/i/$token';

  // Create flow, launched from the centre nav button
  static const create = '/create';

  // Profile (Sprint 9) — everything reachable from the hub at `64:158`.
  static const editProfile = '/profile/edit';
  static const giftsReceived = '/profile/gifts/received';
  static const giftsGiven = '/profile/gifts/given';
  static const giftsOnHold = '/profile/gifts/on-hold';
  static const myEvents = '/profile/events';
  static const addressBook = '/profile/addresses';
  static const helpCentre = '/profile/help';
  static const aboutUs = '/profile/about';

  // Legal. Root-level rather than under `/profile`, because the sign-in screen
  // links to them too — before there is a profile to be under.

  /// Everything under here is readable with or without a session; the router's
  /// redirect lets the whole prefix through.
  static const legal = '/legal';
  static const terms = '$legal/terms';
  static const privacyPolicy = '$legal/privacy';

  // Notifications
  static const notifications = '/notifications';
  static const notificationSettings = '/notifications/settings';

  /// A gift that has arrived (`2012:72`), opened from its notification.
  static String giftArrival(String giftId) => '/gifts/$giftId/arrived';

  /// The thank-you a fulfilled gift drafted (`2015:271`, `2209:104`).
  static String thankYou(String noteId) => '/thank-you/$noteId';

  /// Its preview before sending (`2209:141`, `2227:146`, `2209:156`).
  static String thankYouPreview(String noteId) => '/thank-you/$noteId/preview';

  /// The confirmation after it goes (`2209:203`).
  static String thankYouSent(String noteId) => '/thank-you/$noteId/sent';

  // WishMates — the social graph (Sprint 11).
  //
  // Root-level rather than under `/profile`: the frames are reached from
  // Home's header, and a person's profile is a destination in its own right
  // that chat, search and the request tabs all push to.

  /// Claim an `@handle` (no frame — see `UsernameClaimScreen`). Everything
  /// below it is unreachable until this has been done once.
  static const usernameClaim = '/handle';

  /// "WishMates" (`4177:138`).
  static const wishmates = '/wishmates';

  /// "WishLink" (`4177:77` / `4177:111`) — Received and Sent as two tabs of
  /// one route, because they are the same pending rows seen from either end.
  static const wishlinks = '/wishlinks';

  /// People search (`4177:42`).
  static const peopleSearch = '/people';

  /// Somebody's profile (`4177:217` unconnected, `4177:267` connected). One
  /// route: which one it draws is the relationship the server reports, not a
  /// decision the caller makes.
  static String person(String userId) => '/people/$userId';

  /// The chat list (`4177:179`).
  static const chats = '/chats';

  /// A 1:1 thread (`4177:6`). Keyed by the *person*, not the chat: the caller
  /// always knows who, and `POST /chats/direct/:userId` is idempotent, so the
  /// screen resolves the thread itself rather than every caller doing it.
  static String directChat(String userId) => '/chats/direct/$userId';

  // Settings
  static const appearance = '/profile/appearance';

  /// Order of the four tab branches in the shell — the index the bottom nav
  /// reports maps through this list.
  static const tabBranches = [home, wishlist, memories, profile];
}
