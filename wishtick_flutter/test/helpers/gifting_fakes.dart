import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/events/data/invite_repository.dart';
import 'package:wishtick_flutter/features/events/domain/public_invite.dart';
import 'package:wishtick_flutter/features/gifting/data/gifting_repository.dart';
import 'package:wishtick_flutter/features/gifting/domain/gift.dart';
import 'package:wishtick_flutter/features/gifting/domain/order.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist.dart';

/// A wishlist someone else owns — the only kind you can gift from.
const sharedAccess = AccessDecision(
  canView: true,
  canComment: true,
  canGift: true,
  canManage: false,
  relationship: 'participant',
  role: null,
);

Gift buildGift({
  String id = 'gift_1',
  String itemId = 'item_1',
  String wishlistId = 'wl_1',
  GiftStatus status = GiftStatus.reserved,
  GiftMode mode = GiftMode.online,
  int? amountMinor = 1699900,
  Duration? expiresIn = const Duration(hours: 72),
}) => Gift(
  id: id,
  itemId: itemId,
  wishlistId: wishlistId,
  status: status,
  mode: mode,
  amountMinor: amountMinor,
  currency: 'INR',
  deliveryNotes: null,
  reservedAt: DateTime.now(),
  expiresAt: expiresIn == null ? null : DateTime.now().add(expiresIn),
  createdAt: DateTime.now(),
  history: const [],
);

/// An order with all six stages present, reached up to [stage] — the shape the
/// server always emits.
Order buildOrder({
  String id = 'order_1',
  String giftId = 'gift_1',
  String itemId = 'item_1',
  String reference = 'WTK-20260805-1989',
  OrderStage stage = OrderStage.orderConfirmed,
  DateTime? deliveredAt,
}) {
  final reachedTo = OrderStage.values.indexOf(stage);
  final at = DateTime(2026, 7, 16, 11, 20);
  return Order(
    id: id,
    giftId: giftId,
    itemId: itemId,
    reference: reference,
    stage: stage,
    timeline: [
      for (var i = 0; i < OrderStage.values.length; i++)
        OrderStageView(
          stage: OrderStage.values[i],
          reached: i <= reachedTo,
          at: i <= reachedTo ? at.add(Duration(hours: i)) : null,
          source: i <= reachedTo ? OrderStageSource.gift : null,
          note: null,
        ),
    ],
    amountMinor: 1699900,
    currency: 'INR',
    courier: null,
    trackingNumber: null,
    trackingUrl: null,
    deliveryMethod: null,
    estimatedDeliveryFrom: null,
    estimatedDeliveryTo: null,
    deliveredAt: deliveredAt,
    createdAt: at,
  );
}

PublicInvite buildInvite({
  String title = "Siya's 24th",
  RsvpResponse rsvp = RsvpResponse.pending,
  EventStatus status = EventStatus.published,
  List<InviteWishlistLink> wishlists = const [],
}) => PublicInvite(
  event: InviteEvent(
    title: title,
    type: EventType.birthday,
    startsAt: DateTime.now().add(const Duration(days: 2)),
    endsAt: null,
    timezone: 'Asia/Kolkata',
    description: 'Join us as we celebrate my special day.',
    coverUrl: null,
    status: status,
  ),
  hostFirstName: 'Siya',
  inviteeName: null,
  rsvp: rsvp,
  plusOnes: 0,
  wishlists: wishlists,
);

/// Scriptable stand-in for gifting and orders. Failures are set per call so a
/// test can prove, say, that a lost race leaves the screen usable.
class FakeGiftingRepository implements GiftingRepository {
  FakeGiftingRepository({List<Gift>? gifts, List<Order>? orders})
    : gifts = gifts ?? [],
      orders = orders ?? [];

  final List<Gift> gifts;
  final List<Order> orders;

  ApiException? reserveFailure;
  ApiException? releaseFailure;
  ApiException? purchaseFailure;
  ApiException? orderFailure;

  final reserveCalls = <String>[];
  final releaseCalls = <String>[];
  final purchaseCalls = <String>[];
  final fulfillCalls = <String>[];
  final redirectCalls = <String>[];
  int onHoldCalls = 0;

  /// What `reserve` returns on success; a default gift on this item otherwise.
  Gift? reserveResult;

  @override
  Future<Gift> reserve(
    String itemId, {
    bool? hiddenFromOwner,
    String? idempotencyKey,
  }) async {
    reserveCalls.add(itemId);
    final f = reserveFailure;
    if (f != null) throw f;
    final gift = reserveResult ?? buildGift(itemId: itemId);
    gifts.add(gift);
    return gift;
  }

  @override
  Future<void> release(String itemId) async {
    releaseCalls.add(itemId);
    final f = releaseFailure;
    if (f != null) throw f;
    gifts.removeWhere((g) => g.itemId == itemId);
  }

  @override
  Future<Gift> giftOffline(
    String itemId, {
    String? deliveryNotes,
    DateTime? confirmedAt,
    bool? hiddenFromOwner,
    String? idempotencyKey,
  }) async {
    final gift = buildGift(
      itemId: itemId,
      status: GiftStatus.purchased,
      mode: GiftMode.offline,
      expiresIn: null,
    );
    gifts.add(gift);
    return gift;
  }

  @override
  Future<Gift> purchase(String giftId, {String? note}) async {
    purchaseCalls.add(giftId);
    final f = purchaseFailure;
    if (f != null) throw f;
    return _advance(giftId, GiftStatus.purchased);
  }

  @override
  Future<Gift> fulfill(
    String giftId, {
    String? note,
    String? deliveryNotes,
  }) async {
    fulfillCalls.add(giftId);
    return _advance(giftId, GiftStatus.fulfilled);
  }

  @override
  Future<Gift> complete(String giftId, {String? note}) async =>
      _advance(giftId, GiftStatus.completed);

  @override
  Future<Gift> cancel(String giftId, {String? note}) async =>
      _advance(giftId, GiftStatus.cancelled);

  Gift _advance(String giftId, GiftStatus status) {
    final index = gifts.indexWhere((g) => g.id == giftId);
    if (index == -1) throw StateError('Gift $giftId not found');
    final current = gifts[index];
    final updated = buildGift(
      id: current.id,
      itemId: current.itemId,
      wishlistId: current.wishlistId,
      status: status,
      mode: current.mode,
      amountMinor: current.amountMinor,
      expiresIn: null,
    );
    gifts[index] = updated;
    return updated;
  }

  @override
  Future<List<Gift>> listGiven() async => List.of(gifts);

  @override
  Future<List<Gift>> listOnHold() async {
    onHoldCalls++;
    return gifts
        .where(
          (g) => const {
            GiftStatus.reserved,
            GiftStatus.purchased,
            GiftStatus.fulfilled,
          }.contains(g.status),
        )
        .toList();
  }

  @override
  Future<List<ReceivedGift>> listReceived() async => const [];

  @override
  Future<List<Order>> listOrders() async => List.of(orders);

  @override
  Future<Order> getOrder(String orderId) async {
    final f = orderFailure;
    if (f != null) throw f;
    return orders.firstWhere((o) => o.id == orderId);
  }

  @override
  Future<Order> getOrderForGift(String giftId) async {
    final f = orderFailure;
    if (f != null) throw f;
    return orders.firstWhere(
      (o) => o.giftId == giftId,
      orElse: () => throw const ApiException(
        code: 'NOT_FOUND',
        message: 'Order not found',
        statusCode: 404,
      ),
    );
  }

  @override
  Uri affiliateRedirectUri(String itemId) {
    redirectCalls.add(itemId);
    return Uri.parse('https://wishtick.test/api/v1/r/$itemId');
  }
}

/// Scriptable stand-in for the invite API.
class FakeInviteRepository implements InviteRepository {
  FakeInviteRepository({this.invite});

  /// What `getByToken` returns; replaced by a successful RSVP, as the real
  /// endpoint's response is a freshly resolved invite.
  PublicInvite? invite;
  ApiException? failure;
  ApiException? rsvpFailure;

  final getCalls = <String>[];
  final rsvpCalls = <RsvpResponse>[];

  /// What the invite becomes after a successful RSVP; the same invite with the
  /// new response otherwise.
  PublicInvite? afterRsvp;

  @override
  Future<PublicInvite> getByToken(String token) async {
    getCalls.add(token);
    final f = failure;
    if (f != null) throw f;
    return invite ?? buildInvite();
  }

  @override
  Future<PublicInvite> rsvp(
    String token, {
    required RsvpResponse response,
    int? plusOnes,
    String? message,
    String? name,
  }) async {
    rsvpCalls.add(response);
    final f = rsvpFailure;
    if (f != null) throw f;
    invite = afterRsvp ?? buildInvite(rsvp: response);
    return invite!;
  }
}
