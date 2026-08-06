import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/core/dev/dev_gifting_repositories.dart';
import 'package:wishtick_flutter/core/dev/dev_repositories.dart';
import 'package:wishtick_flutter/features/events/domain/public_invite.dart';
import 'package:wishtick_flutter/features/gifting/domain/gift.dart';
import 'package:wishtick_flutter/features/gifting/domain/order.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist_item.dart';

/// The seeded list you do not own — the only one the gifting flow can act on.
const _friendItemId = 'dev-item-22';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late DevWishlistRepository wishlists;
  late DevGiftingRepository gifting;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    wishlists = DevWishlistRepository(prefs);
    gifting = DevGiftingRepository(prefs);
    // Seeding runs on first read, and the gifting fake works off the store it
    // populates.
    await wishlists.listMine();
  });

  group('seed', () {
    test('exactly one seeded list is gift-able, and it is not yours', () async {
      final mine = await wishlists.listMine();
      final shared = await wishlists.listSharedWithMe();

      expect(mine.every((w) => w.access.canGift == false), isTrue);
      expect(mine.every((w) => w.access.canManage), isTrue);
      expect(shared, hasLength(1));
      expect(shared.single.title, "Siya's Wishlist");
      expect(shared.single.access.canGift, isTrue);
      expect(shared.single.access.canManage, isFalse);
    });

    test("the friend's items carry what the gift summary shows", () async {
      final shared = await wishlists.listSharedWithMe();
      final items = await wishlists.listItems(shared.single.id);

      expect(items, hasLength(6));
      expect(items.every((i) => i.recipientName == 'Siya'), isTrue);
      expect(items.every((i) => i.occasionKey == 'birthday'), isTrue);
      expect(items.every((i) => i.productLink != null), isTrue);
    });
  });

  group('reserve', () {
    test('claims the item in the store the wishlist screen reads', () async {
      final shared = await wishlists.listSharedWithMe();
      final gift = await gifting.reserve(_friendItemId);

      expect(gift.status, GiftStatus.reserved);
      expect(gift.expiresAt, isNotNull);

      final item = await wishlists.getItem(shared.single.id, _friendItemId);
      expect(item.status, WishlistItemStatus.reserved);
    });

    test('a second reserver is turned away', () async {
      await gifting.reserve(_friendItemId);

      expect(() => gifting.reserve(_friendItemId), throwsA(isA<StateError>()));
    });

    test('releasing puts the item back', () async {
      final shared = await wishlists.listSharedWithMe();
      await gifting.reserve(_friendItemId);
      await gifting.release(_friendItemId);

      final item = await wishlists.getItem(shared.single.id, _friendItemId);
      expect(item.status, WishlistItemStatus.available);
      // And the next person can take it.
      await gifting.reserve(_friendItemId);
    });
  });

  group('orders', () {
    test('purchasing an online gift mints an order', () async {
      final gift = await gifting.reserve(_friendItemId);
      await gifting.purchase(gift.id);

      final order = await gifting.getOrderForGift(gift.id);
      expect(order.reference, startsWith('WTK-'));
      expect(order.stage, OrderStage.orderConfirmed);
      expect(order.timeline, hasLength(OrderStage.values.length));
      expect(order.timeline.first.reached, isTrue);
      expect(order.timeline.last.reached, isFalse);
    });

    test('an offline gift has nothing to track', () async {
      final gift = await gifting.giftOffline(_friendItemId);

      expect(gift.mode, GiftMode.offline);
      expect(gift.status, GiftStatus.purchased);
      expect(
        () => gifting.getOrderForGift(gift.id),
        throwsA(isA<StateError>()),
      );
    });

    test('carrier fields stay null — there is no logistics feed', () async {
      final gift = await gifting.reserve(_friendItemId);
      await gifting.purchase(gift.id);
      final order = await gifting.getOrderForGift(gift.id);

      expect(order.hasCarrierInfo, isFalse);
      expect(order.hasEstimatedDelivery, isFalse);
    });

    test('fulfilling delivers the order and stamps the date', () async {
      final gift = await gifting.reserve(_friendItemId);
      await gifting.purchase(gift.id);
      await gifting.fulfill(gift.id);

      final order = await gifting.getOrderForGift(gift.id);
      expect(order.isDelivered, isTrue);
      expect(order.deliveredAt, isNotNull);
      expect(order.timeline.last.reached, isTrue);
    });
  });

  group('invites', () {
    test('the wishlist appears only once you have said yes', () async {
      final invites = DevInviteRepository(prefs);

      final before = await invites.getByToken('dev-invite-1');
      expect(before.rsvp, RsvpResponse.pending);
      expect(before.wishlists, isEmpty);

      final after = await invites.rsvp(
        'dev-invite-1',
        response: RsvpResponse.yes,
      );
      expect(after.rsvp, RsvpResponse.yes);
      expect(after.wishlists, hasLength(1));
    });

    test('a no keeps the wishlist hidden', () async {
      final invites = DevInviteRepository(prefs);
      final after = await invites.rsvp(
        'dev-invite-1',
        response: RsvpResponse.no,
      );

      expect(after.wishlists, isEmpty);
    });
  });
}
