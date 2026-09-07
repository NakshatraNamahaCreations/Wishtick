import '../../../core/router/app_routes.dart';

/// Where a notification goes when it is opened.
///
/// Shared by the notification centre and by a tapped push, which must agree:
/// the same notification arriving as a row and as a lock-screen banner is the
/// same notification, and landing somewhere different depending on which one
/// the reader touched would be a bug nobody could describe.
///
/// Unknown types deliberately go nowhere rather than guessing. The server adds
/// types faster than the client ships, and a wrong destination is worse than an
/// inert row — a push is worse still, because it interrupts to do it.
String? destinationFor(String type, String refId) => switch (type) {
  'gift_fulfilled' || 'group_gift_fulfilled' => AppRoutes.giftArrival(refId),
  'thank_you' => AppRoutes.thankYou(refId),
  'memory_unlocked' => AppRoutes.memory(refId),
  'event_reminder' => AppRoutes.myEvents,
  // The refId is a pair, not an id — two members asking the same friend must
  // collapse to one row — so this goes to the list rather than trying to
  // address one group.
  'group_gift_invite' => AppRoutes.groupGiftInvites,
  'group_gift_funded' ||
  'group_gift_contribution' ||
  'group_gift_joined' ||
  'group_gift_purchased' => AppRoutes.groupGift(refId),
  _ => null,
};
