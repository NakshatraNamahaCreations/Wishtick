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

/// Figma `299:1620` — "Gift Delivered!".
///
/// The mock's subtitle names the recipient ("Siya has received the gift"). An
/// order carries no recipient — it belongs to the gifter, and the wishlist
/// owner's name is not on it — so the line is written without one rather than
/// fetched from a second call whose only job would be to fill in a name.
class OrderDeliveredScreen extends ConsumerStatefulWidget {
  const OrderDeliveredScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderDeliveredScreen> createState() =>
      _OrderDeliveredScreenState();
}

class _OrderDeliveredScreenState extends ConsumerState<OrderDeliveredScreen> {
  OrderRef get _ref => OrderRef(widget.orderId, OrderLookup.byOrderId);

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
    final deliveredAt = order?.deliveredAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Order Delivered')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              const Spacer(),
              // The mock's mark is a gold-ribboned magenta gift box. No such
              // asset exists yet, so the closest icon in the plum-magenta the
              // mock uses — never the gold, which reads as a different brand
              // colour entirely.
              CelebrationMark(
                child: Icon(
                  Icons.card_giftcard,
                  size: 120,
                  color: colors.accent,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Gift Delivered!',
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium.copyWith(
                  color: context.headlineBrandColor,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'The gift has been received.',
                textAlign: TextAlign.center,
                style: context.text.bodyLarge?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              if (state.error != null)
                WishtickErrorText(state.error!)
              else if (deliveredAt != null) ...[
                Text(
                  'Delivered On',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  DateFormat('d MMM yyyy').format(deliveredAt.toLocal()),
                  style: context.text.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Back to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
