import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/gifting_repository.dart';
import '../domain/order.dart';

/// How an order was asked for.
///
/// The two are one controller because the screens are the same either way:
/// only the lookup differs, and a purchase knows its gift long before it knows
/// the order the gift produced.
enum OrderLookup { byOrderId, byGiftId }

@immutable
class OrderRef {
  const OrderRef(this.id, this.lookup);

  final String id;
  final OrderLookup lookup;

  @override
  bool operator ==(Object other) =>
      other is OrderRef && other.id == id && other.lookup == lookup;

  @override
  int get hashCode => Object.hash(id, lookup);
}

@immutable
class OrderState {
  const OrderState({this.order, this.error, this.busy = false});

  final Order? order;
  final String? error;
  final bool busy;

  OrderState copyWith({
    Order? order,
    String? error,
    bool? busy,
    bool clearError = false,
  }) => OrderState(
    order: order ?? this.order,
    error: clearError ? null : (error ?? this.error),
    busy: busy ?? this.busy,
  );
}

class OrderController extends Notifier<OrderState> {
  OrderController(this.arg);

  final OrderRef arg;

  @override
  OrderState build() => const OrderState();

  GiftingRepository get _repo => ref.read(giftingRepositoryProvider);

  Future<void> ensureLoaded() async {
    if (state.order != null) return;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final order = switch (arg.lookup) {
        OrderLookup.byOrderId => await _repo.getOrder(arg.id),
        OrderLookup.byGiftId => await _repo.getOrderForGift(arg.id),
      };
      state = OrderState(order: order);
    } on ApiException catch (e) {
      state = state.copyWith(
        busy: false,
        // A 404 here is not a broken link: an offline gift never gets an
        // order, and saying so is more use than "not found".
        error: e.statusCode == 404
            ? 'There is no order to track for this gift.'
            : e.message,
      );
    }
  }

  /// The gifter reporting that it arrived.
  ///
  /// With no courier feed there is nothing else that can move an order past
  /// "confirmed", so this is deliberately a person's word — recorded on the
  /// timeline with `source: gift`, never dressed up as a carrier scan.
  Future<bool> markDelivered() async {
    final order = state.order;
    if (order == null) return false;

    state = state.copyWith(busy: true, clearError: true);
    try {
      await _repo.fulfill(order.giftId);
      await refresh();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }
}

final orderProvider =
    NotifierProvider.family<OrderController, OrderState, OrderRef>(
      OrderController.new,
    );
