import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../domain/order.dart';
import 'order_controller.dart';

/// Figma `299:1513` — "Track Order".
///
/// The six timeline rows always render, reached or not, because the server
/// always returns all six. Every carrier field above them is null until a
/// logistics feed exists, so the header says so rather than printing a
/// plausible courier name and tracking number.
class TrackOrderScreen extends ConsumerStatefulWidget {
  const TrackOrderScreen({required this.orderRef, super.key});

  /// By order id from a list, or by gift id straight after a purchase.
  final OrderRef orderRef;

  @override
  ConsumerState<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends ConsumerState<TrackOrderScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(orderProvider(widget.orderRef).notifier).ensureLoaded(),
    );
  }

  Future<void> _markDelivered() async {
    final ok = await ref
        .read(orderProvider(widget.orderRef).notifier)
        .markDelivered();
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(orderProvider(widget.orderRef)).error;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    final order = ref.read(orderProvider(widget.orderRef)).order;
    if (order != null) {
      await context.push<void>(AppRoutes.orderDelivered(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderProvider(widget.orderRef));
    final order = state.order;

    return Scaffold(
      appBar: AppBar(title: const Text('Track Order')),
      body: SafeArea(
        child: switch ((order, state.error)) {
          (_, final String message) => Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WishtickErrorText(message),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => unawaited(
                    ref.read(orderProvider(widget.orderRef).notifier).refresh(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          (final Order loaded, _) => Column(
            children: [
              _DeliveryHeader(order: loaded),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  children: [
                    for (var i = 0; i < loaded.timeline.length; i++)
                      _TimelineRow(
                        step: loaded.timeline[i],
                        isFirst: i == 0,
                        isLast: i == loaded.timeline.length - 1,
                      ),
                  ],
                ),
              ),
              if (!loaded.isDelivered)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: state.busy
                          ? null
                          : () => unawaited(_markDelivered()),
                      // Wishtick has no courier feed, so an order can only
                      // reach "delivered" if the person who bought it says so.
                      child: const Text('It has arrived'),
                    ),
                  ),
                ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// The mock's four-line header: delivery method, partner, estimate, tracking
/// number. Each line appears only when there is a real value behind it.
class _DeliveryHeader extends StatelessWidget {
  const _DeliveryHeader({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final estimate = _estimateLine(order);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line(label: 'Order ID', value: order.reference),
          if (order.deliveryMethod != null)
            _Line(label: 'Delivery Method', value: order.deliveryMethod!),
          if (order.courier != null)
            _Line(label: 'Delivery Partner', value: order.courier!),
          if (estimate != null)
            _Line(label: 'Estimated delivery time', value: estimate),
          if (order.trackingNumber != null)
            _TrackingLine(number: order.trackingNumber!),
          if (!order.hasCarrierInfo) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The store handles shipping for this gift, so courier details '
              'come from their confirmation rather than from Wishtick.',
              style: context.text.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String? _estimateLine(Order order) {
    if (!order.hasEstimatedDelivery) return null;
    final format = DateFormat('EEE, d MMM');
    final from = order.estimatedDeliveryFrom;
    final to = order.estimatedDeliveryTo;
    if (from != null && to != null) {
      return '${format.format(from)} - ${format.format(to)}';
    }
    return format.format((from ?? to)!);
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        '$label: $value',
        style: context.text.bodyMedium?.copyWith(color: colors.textPrimary),
      ),
    );
  }
}

class _TrackingLine extends StatelessWidget {
  const _TrackingLine({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Text(
          'Tracking No: $number',
          style: context.text.bodyMedium?.copyWith(color: colors.textPrimary),
        ),
        IconButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: number));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tracking number copied.')),
            );
          },
          icon: const Icon(Icons.copy, size: AppSizes.iconSm),
          tooltip: 'Copy tracking number',
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isFirst,
    required this.isLast,
  });

  final OrderStageView step;
  final bool isFirst;
  final bool isLast;

  static const _dotSize = AppSizes.avatarSm;

  IconData get _icon => switch (step.stage) {
    OrderStage.orderConfirmed => Icons.check,
    OrderStage.paymentConfirmed => Icons.receipt_long,
    OrderStage.processing => Icons.inventory_2_outlined,
    OrderStage.shipped => Icons.local_shipping_outlined,
    OrderStage.outForDelivery => Icons.delivery_dining,
    OrderStage.delivered => Icons.home_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reached = step.reached;
    final at = step.at;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: _dotSize,
                height: _dotSize,
                decoration: BoxDecoration(
                  color: reached
                      ? (isFirst ? colors.success : colors.primaryDeep)
                      : colors.border,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon,
                  size: AppSizes.iconSm,
                  color: reached ? colors.onPrimary : colors.textMuted,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    color: reached ? colors.primaryDeep : colors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.stage.label,
                    style: context.text.titleMedium?.copyWith(
                      // headlineBrandColor, not `primary`: plum is 1.61:1 on
                      // the dark page, and a reached stage must read as more
                      // prominent than the pending ones below it, not less.
                      color: reached
                          ? context.headlineBrandColor
                          : colors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    // Three distinct states, never a blank or an invented
                    // time. A stage can be behind the order and still carry no
                    // timestamp — carriers skip reports, and the server marks
                    // everything before the current stage reached — so calling
                    // that "Pending" under a filled dot would read as broken.
                    switch ((reached, at)) {
                      (false, _) => 'Pending',
                      (true, null) => 'Not reported',
                      (true, final DateTime stamp) => DateFormat(
                        'EEE, d MMM  hh:mm a',
                      ).format(stamp.toLocal()),
                    },
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  if (step.note != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      step.note!,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
