import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/router/app_routes.dart';
import 'package:wishtick_flutter/features/notifications/presentation/notification_destination.dart';

/// Where a notification opens.
///
/// Shared by the notification centre and by a tapped push, so this is the one
/// place the two can disagree — and a push landing somewhere different from the
/// row for the same notification is a bug nobody could describe.
void main() {
  test('a delivered gift opens the arrival screen', () {
    expect(
      destinationFor('gift_fulfilled', 'gift_1'),
      AppRoutes.giftArrival('gift_1'),
    );
    expect(
      destinationFor('group_gift_fulfilled', 'gift_1'),
      AppRoutes.giftArrival('gift_1'),
    );
  });

  test('a thank-you opens the note, a memory opens the capsule', () {
    expect(destinationFor('thank_you', 'ty_1'), AppRoutes.thankYou('ty_1'));
    expect(destinationFor('memory_unlocked', 'm_1'), AppRoutes.memory('m_1'));
  });

  // The refId is a pair, not an id — two members asking the same friend
  // collapse to one row — so addressing one group would be addressing nothing.
  test('a group-gift invitation opens the list, not a group', () {
    expect(
      destinationFor('group_gift_invite', 'gg_1:u_2'),
      AppRoutes.groupGiftInvites,
    );
  });

  test('the money types open the group they are about', () {
    for (final type in [
      'group_gift_funded',
      'group_gift_contribution',
      'group_gift_joined',
      'group_gift_purchased',
    ]) {
      expect(
        destinationFor(type, 'gg_1'),
        AppRoutes.groupGift('gg_1'),
        reason: type,
      );
    }
  });

  // The refId is `{eventId}:{offset}`, which addresses no single screen.
  test('an event reminder opens My Events', () {
    expect(destinationFor('event_reminder', 'ev_1:t-1d'), AppRoutes.myEvents);
  });

  // The server adds types faster than the client ships. A wrong destination is
  // worse than an inert row — and worse still as a push, which interrupts to
  // get it wrong.
  test('a type this build has never heard of goes nowhere', () {
    expect(destinationFor('something_shipped_after_this_build', 'x_1'), isNull);
    expect(destinationFor('', ''), isNull);
  });
}
