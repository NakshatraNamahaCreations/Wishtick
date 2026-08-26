import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/idempotency_key.dart';
import '../domain/gift.dart';
import '../domain/gift_list_item.dart';
import '../domain/order.dart';

/// Talks to the backend's `gifting` and `orders` modules.
///
/// The two live behind one repository because a screen never wants one without
/// the other: reserving produces a gift, purchasing it produces an order, and
/// the confirmation screen reads both.
class GiftingRepository {
  GiftingRepository(this._api);

  final ApiClient _api;

  // ── Reserve / release ───────────────────────────────────────────────────

  /// Claims an item.
  ///
  /// [idempotencyKey] must be minted **once per user intent** and reused for
  /// every retry of it — see [newIdempotencyKey]. Callers that omit it get a
  /// fresh key, which is right for a first attempt and wrong for a retry.
  ///
  /// Throws [ApiException] with `ITEM_NOT_AVAILABLE` or `ITEM_ALREADY_CLAIMED`
  /// (both 409, both meaning someone else got there first),
  /// `CANNOT_GIFT_OWN_ITEM` (403), or 404 when the caller cannot see the item
  /// at all.
  Future<Gift> reserve(
    String itemId, {
    bool? hiddenFromOwner,
    String? idempotencyKey,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/items/$itemId/reserve',
      body: {'hiddenFromOwner': ?hiddenFromOwner},
      headers: {'Idempotency-Key': idempotencyKey ?? newIdempotencyKey()},
    );
    return Gift.fromJson(json);
  }

  /// Gives the item back. 204 with no body, so nothing is parsed.
  Future<void> release(String itemId) =>
      _api.delete<void>('/items/$itemId/reserve');

  /// Records a gift bought somewhere Wishtick had no part in. Lands straight at
  /// purchased, and mints no order — there is nothing to track.
  Future<Gift> giftOffline(
    String itemId, {
    String? deliveryNotes,
    DateTime? confirmedAt,
    bool? hiddenFromOwner,
    String? idempotencyKey,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/items/$itemId/gift-offline',
      body: {
        'deliveryNotes': ?deliveryNotes,
        'confirmedAt': ?confirmedAt?.toIso8601String(),
        'hiddenFromOwner': ?hiddenFromOwner,
      },
      headers: {'Idempotency-Key': idempotencyKey ?? newIdempotencyKey()},
    );
    return Gift.fromJson(json);
  }

  // ── Transitions ─────────────────────────────────────────────────────────
  //
  // An illegal move throws `INVALID_GIFT_TRANSITION` (409) whose `details`
  // carry `{from, to, allowed}`. Drive buttons off `allowed` rather than
  // re-deriving the state machine here — the server owns it.

  Future<Gift> purchase(String giftId, {String? note}) =>
      _transition(giftId, 'purchase', note: note);

  Future<Gift> fulfill(String giftId, {String? note, String? deliveryNotes}) =>
      _transition(giftId, 'fulfill', note: note, deliveryNotes: deliveryNotes);

  Future<Gift> complete(String giftId, {String? note}) =>
      _transition(giftId, 'complete', note: note);

  Future<Gift> cancel(String giftId, {String? note}) =>
      _transition(giftId, 'cancel', note: note);

  Future<Gift> _transition(
    String giftId,
    String action, {
    String? note,
    String? deliveryNotes,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/gifts/$giftId/$action',
      body: {'note': ?note, 'deliveryNotes': ?deliveryNotes},
    );
    return Gift.fromJson(json);
  }

  // ── The three list screens ──────────────────────────────────────────────
  //
  // All three answer [GiftListItem], not [Gift]: the cards need the item's
  // photo, title and price and the other person's first name, and the server
  // joins those in one query rather than leaving the client to fetch each row.

  /// "Gifts Given" (`324:1253`) — everything the caller is giving, single or
  /// group, in any state.
  Future<List<GiftListItem>> listGiven() => _giftList('/gifts/given');

  /// "Gifts On Hold" (`324:1210`) — reserved, purchased or fulfilled.
  Future<List<GiftListItem>> listOnHold() => _giftList('/gifts/on-hold');

  /// "Gifts Received" (`324:1108`).
  ///
  /// A surprise still in progress is omitted server-side — not merely
  /// anonymised — so this list can never hint that something is coming.
  Future<List<GiftListItem>> listReceived() => _giftList('/gifts/received');

  Future<List<GiftListItem>> _giftList(String path) async {
    final json = await _api.get<List<dynamic>>(path);
    return json
        .map((e) => GiftListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Orders ──────────────────────────────────────────────────────────────

  Future<List<Order>> listOrders() async {
    final json = await _api.get<List<dynamic>>('/orders/mine');
    return json.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> getOrder(String orderId) async {
    final json = await _api.get<Map<String, dynamic>>('/orders/$orderId');
    return Order.fromJson(json);
  }

  /// The order behind a gift, so the confirmation screen can follow straight on
  /// from a purchase instead of hunting the order list for the one just made.
  ///
  /// 404s for an offline gift, which by design has no order.
  Future<Order> getOrderForGift(String giftId) async {
    final json = await _api.get<Map<String, dynamic>>('/gifts/$giftId/order');
    return Order.fromJson(json);
  }

  // ── Affiliate redirect ──────────────────────────────────────────────────

  /// The URL "Gift Now" opens.
  ///
  /// `GET /api/v1/r/:itemId` answers 302 to the merchant with Wishtick's
  /// affiliate tag attached, so it must be handed to the browser — following it
  /// with the API client would swallow the redirect and lose the attribution
  /// cookie. It also records the click, which is why the app must not
  /// short-circuit to the product's own `productLink`.
  Uri affiliateRedirectUri(String itemId) =>
      Uri.parse('${ApiConfig.baseUrl}/r/$itemId');

  /// The URL a seller row — and "Gift Now" — opens for a catalogue product.
  ///
  /// Unlike [affiliateRedirectUri] this needs nothing saved first: the product
  /// page is reached from search, where no wishlist item exists yet.
  ///
  /// [offerIndex] names one seller out of the product's list, so the click
  /// goes to *that* merchant rather than to whichever one happened to be
  /// converted first. Omit it for the product's own link.
  Uri productRedirectUri(
    String provider,
    String externalId, {
    int? offerIndex,
  }) {
    final path = '${ApiConfig.baseUrl}/r/p/$provider/$externalId';
    return Uri.parse(offerIndex == null ? path : '$path?offer=$offerIndex');
  }
}

final giftingRepositoryProvider = Provider<GiftingRepository>((ref) {
  return GiftingRepository(ref.watch(apiClientProvider));
});
