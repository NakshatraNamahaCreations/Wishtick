import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/idempotency_key.dart';
import '../domain/gift.dart';
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

  // ── Dashboard sections ──────────────────────────────────────────────────

  /// Everything the caller is giving, in any state.
  Future<List<Gift>> listGiven() => _giftList('/gifts/given');

  /// Still in the caller's hands — reserved, purchased or fulfilled.
  Future<List<Gift>> listOnHold() => _giftList('/gifts/on-hold');

  /// Gifts coming *to* the caller. A much smaller shape than [Gift]: surprises
  /// still in progress are omitted server-side, and the gifter is never named.
  Future<List<ReceivedGift>> listReceived() async {
    final json = await _api.get<List<dynamic>>('/gifts/received');
    return json
        .map((e) => ReceivedGift.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Gift>> _giftList(String path) async {
    final json = await _api.get<List<dynamic>>(path);
    return json.map((e) => Gift.fromJson(e as Map<String, dynamic>)).toList();
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
}

final giftingRepositoryProvider = Provider<GiftingRepository>((ref) {
  return GiftingRepository(ref.watch(apiClientProvider));
});
