import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/events/data/invite_repository.dart';
import '../../features/events/domain/public_invite.dart';
import '../../features/gifting/data/gifting_repository.dart';
import '../../features/gifting/domain/gift.dart';
import '../../features/gifting/domain/order.dart';
import 'dev_keys.dart';

/// Reservation window. The backend's default TTL is 72h; the reserve sheet mock
/// shows 48:00:00. The fake uses the backend's number so the countdown here and
/// on a real server agree — the screen renders whatever `expiresAt` says rather
/// than a hardcoded figure.
const _holdDuration = Duration(hours: 72);

/// Gifting and orders against SharedPreferences.
///
/// Reserving writes the item's status back into the very store
/// `DevWishlistRepository` reads, so an item reserved here shows as "Reserved"
/// on the wishlist screen — the join the real backend makes inside a
/// transaction, done here by rewriting one row.
class DevGiftingRepository implements GiftingRepository {
  DevGiftingRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _latency = Duration(milliseconds: 300);

  // ── Stores ──────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _read(String key) =>
      (jsonDecode(_prefs.getString(key) ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<void> _write(String key, List<Map<String, dynamic>> rows) =>
      _prefs.setString(key, jsonEncode(rows));

  /// Flips one item's status in the wishlist store the wishlist fake owns.
  Future<void> _setItemStatus(String itemId, String status) async {
    final items = _read(DevKeys.wishlistItems);
    final index = items.indexWhere((i) => i['id'] == itemId);
    if (index == -1) return;
    items[index]['status'] = status;
    await _write(DevKeys.wishlistItems, items);
  }

  Map<String, dynamic>? _item(String itemId) {
    for (final row in _read(DevKeys.wishlistItems)) {
      if (row['id'] == itemId) return row;
    }
    return null;
  }

  // ── Reserve / release ───────────────────────────────────────────────────

  @override
  Future<Gift> reserve(
    String itemId, {
    bool? hiddenFromOwner,
    String? idempotencyKey,
  }) async {
    await Future<void>.delayed(_latency);

    final item = _item(itemId);
    if (item == null) throw StateError('Item $itemId not found');
    if ((item['status'] as String? ?? 'available') != 'available') {
      // Same message class the real 409 carries: someone else got there first.
      throw StateError('This item has already been claimed');
    }

    final now = DateTime.now();
    final price = item['price'] as Map<String, dynamic>? ?? const {};
    final row = {
      'id': 'dev-gift-${now.microsecondsSinceEpoch}',
      'itemId': itemId,
      'wishlistId': item['wishlistId'],
      'type': 'individual',
      'mode': 'online',
      'status': 'reserved',
      'amountMinor': price['amountMinor'],
      'currency': price['currency'] ?? 'INR',
      'deliveryNotes': null,
      'reservedAt': now.toIso8601String(),
      'expiresAt': now.add(_holdDuration).toIso8601String(),
      'createdAt': now.toIso8601String(),
      'history': [
        {'status': 'reserved', 'at': now.toIso8601String(), 'note': null},
      ],
    };

    await _write(DevKeys.gifts, [..._read(DevKeys.gifts), row]);
    await _setItemStatus(itemId, 'reserved');
    return Gift.fromJson(row);
  }

  @override
  Future<void> release(String itemId) async {
    await Future<void>.delayed(_latency);
    final gifts = _read(DevKeys.gifts);
    final index = gifts.indexWhere(
      (g) => g['itemId'] == itemId && g['status'] == 'reserved',
    );
    if (index == -1) throw StateError('No active reservation');

    gifts[index]['status'] = 'cancelled';
    await _write(DevKeys.gifts, gifts);
    await _setItemStatus(itemId, 'available');
  }

  @override
  Future<Gift> giftOffline(
    String itemId, {
    String? deliveryNotes,
    DateTime? confirmedAt,
    bool? hiddenFromOwner,
    String? idempotencyKey,
  }) async {
    final gift = await reserve(itemId, hiddenFromOwner: hiddenFromOwner);

    final gifts = _read(DevKeys.gifts);
    final index = gifts.indexWhere((g) => g['id'] == gift.id);
    final at = (confirmedAt ?? DateTime.now()).toIso8601String();
    gifts[index]['mode'] = 'offline';
    gifts[index]['status'] = 'purchased';
    gifts[index]['deliveryNotes'] = deliveryNotes;
    // An offline gift is not on hold, so nothing expires.
    gifts[index]['expiresAt'] = null;
    (gifts[index]['history'] as List).add({
      'status': 'purchased',
      'at': at,
      'note': null,
    });

    await _write(DevKeys.gifts, gifts);
    await _setItemStatus(itemId, 'gifted_offline');
    // Deliberately no order: an offline gift was bought elsewhere and has
    // nothing to track, exactly as the real listener decides.
    return Gift.fromJson(gifts[index]);
  }

  // ── Transitions ─────────────────────────────────────────────────────────

  @override
  Future<Gift> purchase(String giftId, {String? note}) async {
    final gift = await _advanceGift(giftId, 'purchased', note: note);
    await _setItemStatus(gift.itemId, 'purchased');
    if (gift.mode == GiftMode.online) await _createOrder(gift);
    return gift;
  }

  @override
  Future<Gift> fulfill(
    String giftId, {
    String? note,
    String? deliveryNotes,
  }) async {
    final gift = await _advanceGift(
      giftId,
      'fulfilled',
      note: note,
      deliveryNotes: deliveryNotes,
    );
    await _setItemStatus(gift.itemId, 'fulfilled');
    await _advanceOrder(giftId, OrderStage.delivered);
    return gift;
  }

  @override
  Future<Gift> complete(String giftId, {String? note}) async {
    final gift = await _advanceGift(giftId, 'completed', note: note);
    await _setItemStatus(gift.itemId, 'completed');
    return gift;
  }

  @override
  Future<Gift> cancel(String giftId, {String? note}) async {
    final gift = await _advanceGift(giftId, 'cancelled', note: note);
    await _setItemStatus(gift.itemId, 'available');
    return gift;
  }

  Future<Gift> _advanceGift(
    String giftId,
    String status, {
    String? note,
    String? deliveryNotes,
  }) async {
    await Future<void>.delayed(_latency);
    final gifts = _read(DevKeys.gifts);
    final index = gifts.indexWhere((g) => g['id'] == giftId);
    if (index == -1) throw StateError('Gift $giftId not found');

    final row = gifts[index];
    row['status'] = status;
    if (deliveryNotes != null) row['deliveryNotes'] = deliveryNotes;
    // A purchased gift is no longer on a clock.
    if (status != 'reserved') row['expiresAt'] = null;
    (row['history'] as List).add({
      'status': status,
      'at': DateTime.now().toIso8601String(),
      'note': note,
    });

    await _write(DevKeys.gifts, gifts);
    return Gift.fromJson(row);
  }

  // ── Dashboard sections ──────────────────────────────────────────────────

  @override
  Future<List<Gift>> listGiven() async {
    await Future<void>.delayed(_latency);
    return _read(DevKeys.gifts).map(Gift.fromJson).toList().reversed.toList();
  }

  @override
  Future<List<Gift>> listOnHold() async {
    final all = await listGiven();
    return all
        .where(
          (g) => const {
            GiftStatus.reserved,
            GiftStatus.purchased,
            GiftStatus.fulfilled,
          }.contains(g.status),
        )
        .toList();
  }

  /// Always empty: everything the dev session reserves, it reserves as the
  /// gifter. Inventing incoming gifts would put a surprise in front of the very
  /// person the real backend hides it from.
  @override
  Future<List<ReceivedGift>> listReceived() async {
    await Future<void>.delayed(_latency);
    return const [];
  }

  // ── Orders ──────────────────────────────────────────────────────────────

  Future<void> _createOrder(Gift gift) async {
    final orders = _read(DevKeys.orders);
    if (orders.any((o) => o['giftId'] == gift.id)) return;

    final now = DateTime.now();
    orders.add({
      'id': 'dev-order-${now.microsecondsSinceEpoch}',
      'giftId': gift.id,
      'itemId': gift.itemId,
      'reference': _mintReference(now),
      'stage': OrderStage.orderConfirmed.wireValue,
      'timeline': [
        {
          'stage': OrderStage.orderConfirmed.wireValue,
          'at': now.toIso8601String(),
          'source': OrderStageSource.gift.wireValue,
          'note': null,
        },
      ],
      'amountMinor': gift.amountMinor,
      'currency': gift.currency,
      // Every carrier field stays null: there is no logistics feed to fill
      // them, and a plausible-looking courier name would be a lie the screen
      // then renders as fact.
      'courier': null,
      'trackingNumber': null,
      'trackingUrl': null,
      'deliveryMethod': null,
      'estimatedDeliveryFrom': null,
      'estimatedDeliveryTo': null,
      'deliveredAt': null,
      'createdAt': now.toIso8601String(),
    });
    await _write(DevKeys.orders, orders);
  }

  Future<void> _advanceOrder(String giftId, OrderStage stage) async {
    final orders = _read(DevKeys.orders);
    final index = orders.indexWhere((o) => o['giftId'] == giftId);
    if (index == -1) return;

    final now = DateTime.now();
    orders[index]['stage'] = stage.wireValue;
    (orders[index]['timeline'] as List).add({
      'stage': stage.wireValue,
      'at': now.toIso8601String(),
      'source': OrderStageSource.gift.wireValue,
      'note': null,
    });
    if (stage == OrderStage.delivered) {
      orders[index]['deliveredAt'] = now.toIso8601String();
    }
    await _write(DevKeys.orders, orders);
  }

  /// Expands a stored order into the all-six-stages shape the real view emits,
  /// so the client sees identical data either way.
  Order _toOrder(Map<String, dynamic> row) {
    final recorded = {
      for (final e in row['timeline'] as List)
        (e as Map)['stage'] as String: Map<String, dynamic>.from(e),
    };
    final current = OrderStage.values.indexOf(
      OrderStage.fromWire(row['stage'] as String?),
    );

    return Order.fromJson({
      ...row,
      'timeline': [
        for (var i = 0; i < OrderStage.values.length; i++)
          () {
            final stage = OrderStage.values[i];
            final entry = recorded[stage.wireValue];
            return {
              'stage': stage.wireValue,
              'reached': entry != null || i <= current,
              'at': entry?['at'],
              'source': entry?['source'],
              'note': entry?['note'],
            };
          }(),
      ],
    });
  }

  @override
  Future<List<Order>> listOrders() async {
    await Future<void>.delayed(_latency);
    return _read(DevKeys.orders).map(_toOrder).toList().reversed.toList();
  }

  @override
  Future<Order> getOrder(String orderId) async {
    await Future<void>.delayed(_latency);
    final row = _read(DevKeys.orders).firstWhere(
      (o) => o['id'] == orderId,
      orElse: () => throw StateError('Order $orderId not found'),
    );
    return _toOrder(row);
  }

  @override
  Future<Order> getOrderForGift(String giftId) async {
    await Future<void>.delayed(_latency);
    final row = _read(DevKeys.orders).firstWhere(
      (o) => o['giftId'] == giftId,
      orElse: () => throw StateError('No order for gift $giftId'),
    );
    return _toOrder(row);
  }

  /// Points at the item's own product link so tapping "Gift Now" in dev mode
  /// still lands somewhere real. The dev catalogue has no link for most items,
  /// in which case there is nothing honest to open.
  @override
  Uri affiliateRedirectUri(String itemId) {
    final link = _item(itemId)?['productLink'] as String?;
    return Uri.parse(link ?? 'https://wishtick.dev/r/$itemId');
  }

  static String _mintReference(DateTime now) {
    final date = now.toIso8601String().substring(0, 10).replaceAll('-', '');
    final suffix = 1000 + Random().nextInt(9000);
    return 'WTK-$date-$suffix';
  }

  /// Lets a screen show something without first walking the whole flow.
  Future<void> seedIfEmpty() async {
    if (_read(DevKeys.gifts).isNotEmpty) return;
    final gift = await reserve('dev-item-2');
    await purchase(gift.id);
  }
}

/// One invite, matching the "Siya's 24th" mock (Figma `291:1008`).
///
/// The RSVP is persisted so the screen behaves like a real one across a
/// restart; everything else is fixed, because there is no local event store to
/// derive it from.
class DevInviteRepository implements InviteRepository {
  DevInviteRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _latency = Duration(milliseconds: 300);

  Map<String, dynamic> _read() =>
      jsonDecode(_prefs.getString(DevKeys.invites) ?? '{}')
          as Map<String, dynamic>;

  @override
  Future<PublicInvite> getByToken(String token) async {
    await Future<void>.delayed(_latency);
    final saved = _read()[token] as Map<String, dynamic>? ?? const {};
    final rsvp = RsvpResponse.fromWire(saved['rsvp'] as String?);

    return PublicInvite.fromJson({
      'event': {
        'title': "Siya's 24th",
        'type': 'birthday',
        'startsAt': DateTime.now()
            .add(const Duration(days: 2))
            .toIso8601String(),
        'endsAt': null,
        'timezone': 'Asia/Kolkata',
        'description':
            'Join us as we celebrate my special day filled with laughter, '
            'love, and unforgettable memories. Your presence will make this '
            'occasion even more meaningful.',
        'coverUrl': null,
        'status': 'published',
      },
      'host': {'firstName': 'Siya'},
      'invitee': {
        'name': saved['name'],
        'rsvp': rsvp.wireValue,
        'plusOnes': saved['plusOnes'] ?? 0,
      },
      // An event-only wishlist appears only once the guest has said yes or
      // maybe — the same gate AccessPolicyService applies server-side.
      'wishlists': rsvp == RsvpResponse.yes || rsvp == RsvpResponse.maybe
          ? [
              {'slug': 'dev-dev-wl-1', 'title': "Siya's Wishlist"},
            ]
          : <Map<String, dynamic>>[],
    });
  }

  @override
  Future<PublicInvite> rsvp(
    String token, {
    required RsvpResponse response,
    int? plusOnes,
    String? message,
    String? name,
  }) async {
    await Future<void>.delayed(_latency);
    final all = _read();
    all[token] = {
      'rsvp': response.wireValue,
      'plusOnes': plusOnes ?? 0,
      'message': message,
      'name': name,
    };
    await _prefs.setString(DevKeys.invites, jsonEncode(all));
    return getByToken(token);
  }
}
