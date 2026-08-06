import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/gifting/data/gifting_repository.dart';
import 'package:wishtick_flutter/features/gifting/domain/order.dart';
import 'package:wishtick_flutter/features/gifting/presentation/order_controller.dart';

import '../../helpers/gifting_fakes.dart';

void main() {
  late FakeGiftingRepository gifting;
  late ProviderContainer container;

  setUp(() {
    gifting = FakeGiftingRepository(
      gifts: [buildGift()],
      orders: [buildOrder()],
    );
    container = ProviderContainer(
      overrides: [giftingRepositoryProvider.overrideWithValue(gifting)],
    );
  });

  tearDown(() => container.dispose());

  test('loads by order id', () async {
    const ref = OrderRef('order_1', OrderLookup.byOrderId);
    await container.read(orderProvider(ref).notifier).ensureLoaded();

    expect(
      container.read(orderProvider(ref)).order?.reference,
      'WTK-20260805-1989',
    );
  });

  test('loads by gift id, for the path straight out of a purchase', () async {
    const ref = OrderRef('gift_1', OrderLookup.byGiftId);
    await container.read(orderProvider(ref).notifier).ensureLoaded();

    expect(container.read(orderProvider(ref)).order?.id, 'order_1');
  });

  test('a gift with no order explains itself rather than 404-ing', () async {
    const ref = OrderRef('gift_offline', OrderLookup.byGiftId);
    await container.read(orderProvider(ref).notifier).ensureLoaded();

    expect(
      container.read(orderProvider(ref)).error,
      'There is no order to track for this gift.',
    );
  });

  test('every stage is present, reached or not', () async {
    const ref = OrderRef('order_1', OrderLookup.byOrderId);
    await container.read(orderProvider(ref).notifier).ensureLoaded();
    final order = container.read(orderProvider(ref)).order!;

    expect(order.timeline.length, OrderStage.values.length);
    expect(order.timeline.first.reached, isTrue);
    expect(order.timeline.last.reached, isFalse);
    // An unreached stage has no time, which is what the screen prints as
    // "Pending" rather than inventing one.
    expect(order.timeline.last.at, isNull);
  });

  test('carrier fields stay null until there is a logistics feed', () async {
    const ref = OrderRef('order_1', OrderLookup.byOrderId);
    await container.read(orderProvider(ref).notifier).ensureLoaded();
    final order = container.read(orderProvider(ref)).order!;

    expect(order.hasCarrierInfo, isFalse);
    expect(order.hasEstimatedDelivery, isFalse);
    expect(order.courier, isNull);
    expect(order.trackingNumber, isNull);
  });

  test('"it has arrived" fulfils the gift behind the order', () async {
    const ref = OrderRef('order_1', OrderLookup.byOrderId);
    final notifier = container.read(orderProvider(ref).notifier);
    await notifier.ensureLoaded();

    gifting.orders[0] = buildOrder(
      stage: OrderStage.delivered,
      deliveredAt: DateTime(2026, 7, 26),
    );

    expect(await notifier.markDelivered(), isTrue);
    expect(gifting.fulfillCalls, ['gift_1']);
    expect(container.read(orderProvider(ref)).order?.isDelivered, isTrue);
  });

  test('currentStep is the last stage that actually happened', () {
    final order = buildOrder(stage: OrderStage.shipped);
    expect(order.currentStep.stage, OrderStage.shipped);
  });
}
