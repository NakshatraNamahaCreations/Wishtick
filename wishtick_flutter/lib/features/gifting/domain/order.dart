import 'package:flutter/foundation.dart';

/// The six rows of the Track Order timeline, in display order.
///
/// The backend returns all six on every order — reached or not — so the client
/// never has to know the running order itself. This enum only names them and
/// supplies labels.
enum OrderStage {
  orderConfirmed('order_confirmed', 'Order Confirmed'),
  paymentConfirmed('payment_confirmed', 'Payment Confirmed'),
  processing('processing', 'Processing'),
  shipped('shipped', 'Shipped'),
  outForDelivery('out_for_delivery', 'Out for Delivery'),
  delivered('delivered', 'Delivered');

  const OrderStage(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static OrderStage fromWire(String? value) => OrderStage.values.firstWhere(
    (v) => v.wireValue == value,
    orElse: () => orderConfirmed,
  );
}

/// Who put a stage on the timeline.
///
/// Kept client-side so the UI can be honest about provenance: a stage sourced
/// from [gift] means a Wishtick state change implied it, not that a carrier
/// scanned anything.
enum OrderStageSource {
  gift('gift'),
  affiliateWebhook('affiliate_webhook'),
  courierWebhook('courier_webhook'),
  manual('manual');

  const OrderStageSource(this.wireValue);

  final String wireValue;

  static OrderStageSource? fromWire(String? value) {
    if (value == null) return null;
    for (final source in OrderStageSource.values) {
      if (source.wireValue == value) return source;
    }
    return null;
  }
}

/// One timeline row.
///
/// [at] is null for a stage that has not happened. That is deliberately the
/// difference between "not yet" and "we don't know" — never render a guessed
/// date in its place.
@immutable
class OrderStageView {
  const OrderStageView({
    required this.stage,
    required this.reached,
    required this.at,
    required this.source,
    required this.note,
  });

  final OrderStage stage;
  final bool reached;
  final DateTime? at;
  final OrderStageSource? source;
  final String? note;

  factory OrderStageView.fromJson(Map<String, dynamic> json) => OrderStageView(
    stage: OrderStage.fromWire(json['stage'] as String?),
    reached: json['reached'] as bool? ?? false,
    at: json['at'] == null ? null : DateTime.parse(json['at'] as String),
    source: OrderStageSource.fromWire(json['source'] as String?),
    note: json['note'] as String?,
  );
}

/// An order the caller placed (`OrderView`).
///
/// Only the gifter ever sees one — the recipient of a surprise must not be able
/// to read a delivery date off it, so the backend scopes every order route to
/// its gifter.
@immutable
class Order {
  const Order({
    required this.id,
    required this.giftId,
    required this.itemId,
    required this.reference,
    required this.stage,
    required this.timeline,
    required this.amountMinor,
    required this.currency,
    required this.courier,
    required this.trackingNumber,
    required this.trackingUrl,
    required this.deliveryMethod,
    required this.estimatedDeliveryFrom,
    required this.estimatedDeliveryTo,
    required this.deliveredAt,
    required this.createdAt,
  });

  final String id;
  final String giftId;
  final String itemId;

  /// The human-facing `WTK-20260805-1989` reference the confirmation screen
  /// shows.
  final String reference;
  final OrderStage stage;

  /// Always six entries, oldest stage first.
  final List<OrderStageView> timeline;
  final int? amountMinor;
  final String currency;

  // Carrier detail. Null until a logistics feed exists — screens must say
  // "not available yet" rather than show a placeholder that reads like real
  // courier data.
  final String? courier;
  final String? trackingNumber;
  final String? trackingUrl;
  final String? deliveryMethod;
  final DateTime? estimatedDeliveryFrom;
  final DateTime? estimatedDeliveryTo;
  final DateTime? deliveredAt;
  final DateTime createdAt;

  bool get isDelivered => stage == OrderStage.delivered;

  /// True when we have nothing a carrier told us — which is every order today.
  bool get hasCarrierInfo => courier != null || trackingNumber != null;

  bool get hasEstimatedDelivery =>
      estimatedDeliveryFrom != null || estimatedDeliveryTo != null;

  /// The most recent stage that actually happened, for the "where is it now"
  /// line. Falls back to the first row, which is always reached.
  OrderStageView get currentStep =>
      timeline.lastWhere((step) => step.reached, orElse: () => timeline.first);

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    giftId: json['giftId'] as String,
    itemId: json['itemId'] as String,
    reference: json['reference'] as String,
    stage: OrderStage.fromWire(json['stage'] as String?),
    timeline: (json['timeline'] as List<dynamic>? ?? const [])
        .map((e) => OrderStageView.fromJson(e as Map<String, dynamic>))
        .toList(),
    amountMinor: json['amountMinor'] as int?,
    currency: json['currency'] as String? ?? 'INR',
    courier: json['courier'] as String?,
    trackingNumber: json['trackingNumber'] as String?,
    trackingUrl: json['trackingUrl'] as String?,
    deliveryMethod: json['deliveryMethod'] as String?,
    estimatedDeliveryFrom: json['estimatedDeliveryFrom'] == null
        ? null
        : DateTime.parse(json['estimatedDeliveryFrom'] as String),
    estimatedDeliveryTo: json['estimatedDeliveryTo'] == null
        ? null
        : DateTime.parse(json['estimatedDeliveryTo'] as String),
    deliveredAt: json['deliveredAt'] == null
        ? null
        : DateTime.parse(json['deliveredAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
