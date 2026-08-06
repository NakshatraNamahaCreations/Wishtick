import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import 'order_controller.dart';
import 'widgets/celebration_mark.dart';

/// Figma `299:1486` — "Your Gift is confirmed!".
///
/// Reached straight after a purchase, so it looks the order up by gift: the
/// order is minted by a domain event the client never sees, and its id is not
/// in the purchase response.
class OrderConfirmedScreen extends ConsumerStatefulWidget {
  const OrderConfirmedScreen({required this.giftId, super.key});

  final String giftId;

  @override
  ConsumerState<OrderConfirmedScreen> createState() =>
      _OrderConfirmedScreenState();
}

class _OrderConfirmedScreenState extends ConsumerState<OrderConfirmedScreen> {
  OrderRef get _ref => OrderRef(widget.giftId, OrderLookup.byGiftId);

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(orderProvider(_ref).notifier).ensureLoaded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderProvider(_ref));
    final colors = context.colors;
    final order = state.order;

    return Scaffold(
      appBar: AppBar(title: const Text('Order Confirmed')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              const Spacer(),
              // The mock's mark is a magenta heart with a tick through it —
              // which is the Wishtick logo, so it is the logo rather than an
              // approximation of one.
              const CelebrationMark(
                child: Image(
                  image: AssetImage('assets/logo/logo.png'),
                  width: 120,
                  height: 120,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Your Gift is confirmed!',
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium.copyWith(
                  color: context.headlineBrandColor,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "We'll notify you once your gift is shipped.",
                textAlign: TextAlign.center,
                style: context.text.bodyLarge?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              if (state.error != null)
                WishtickErrorText(state.error!)
              else if (order == null)
                const CircularProgressIndicator()
              else ...[
                _Detail(label: 'Order ID', value: order.reference),
                const SizedBox(height: AppSpacing.lg),
                _Detail(
                  label: 'Delivery Date',
                  // Null until a courier tells us. The mock prints a date; a
                  // made-up one here would be the single most misleading thing
                  // on the screen.
                  value: order.estimatedDeliveryTo == null
                      ? 'Confirmed by the store at checkout'
                      : DateFormat(
                          'd MMM yyyy',
                        ).format(order.estimatedDeliveryTo!),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: order == null
                      ? null
                      : () => unawaited(
                          context.push<void>(AppRoutes.order(order.id)),
                        ),
                  child: const Text('Track Order'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: context.text.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
