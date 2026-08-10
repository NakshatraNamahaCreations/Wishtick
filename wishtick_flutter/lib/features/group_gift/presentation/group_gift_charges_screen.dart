import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../domain/group_gift.dart';
import 'group_gift_controller.dart';
import 'widgets/add_charge_sheet.dart';
import 'widgets/group_gift_widgets.dart';

/// "Miscellaneous Charges" (`4007:568`).
///
/// Step 3, and the last one before anyone is asked for money — which is why
/// the CTA reads "Proceed to Contribution" and why the Grand Total is settled
/// here rather than at checkout.
class GroupGiftChargesScreen extends ConsumerStatefulWidget {
  const GroupGiftChargesScreen({required this.groupGiftId, super.key});

  final String groupGiftId;

  @override
  ConsumerState<GroupGiftChargesScreen> createState() =>
      _GroupGiftChargesScreenState();
}

class _GroupGiftChargesScreenState
    extends ConsumerState<GroupGiftChargesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(groupGiftProvider(widget.groupGiftId).notifier).ensureLoaded();
    });
  }

  GroupGiftController get _controller =>
      ref.read(groupGiftProvider(widget.groupGiftId).notifier);

  Future<void> _add() async {
    final result = await showAddChargeSheet(context);
    if (result == null || !mounted) return;
    await _controller.addCharge(
      label: result.label,
      amountMinor: result.amountMinor,
    );
  }

  Future<void> _edit(GroupGiftCharge charge) async {
    final result = await showAddChargeSheet(context, existing: charge);
    if (result == null || !mounted) return;
    await _controller.updateCharge(
      charge.id,
      label: result.label,
      amountMinor: result.amountMinor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupGiftProvider(widget.groupGiftId));
    final gift = state.gift;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Miscellaneous Charges')),
      body: gift == null
          ? Center(
              child: state.error != null
                  ? WishtickErrorText(state.error!)
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                OutlinedButton(
                  onPressed: state.busy ? null : _add,
                  child: const Text('+  Add Charge'),
                ),
                if (gift.charges.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  const GroupGiftSectionLabel('Added charges'),
                  const SizedBox(height: AppSpacing.md),
                  for (final charge in gift.charges) ...[
                    ChargeRow(
                      charge: charge,
                      onEdit: state.busy ? null : () => _edit(charge),
                      onDelete: state.busy
                          ? null
                          : () => _controller.removeCharge(charge.id),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
                if (state.error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  WishtickErrorText(state.error!),
                ],
              ],
            ),
      bottomNavigationBar: gift == null
          ? null
          : Container(
              color: colors.background,
              child: GroupGiftFooter(
                label: 'Proceed to Contribution',
                busy: state.busy,
                onPressed: () =>
                    context.go(AppRoutes.groupGiftCreated(gift.id)),
                child: CostSummaryCard(
                  chargesTotalMinor: gift.chargesTotalMinor,
                  grandTotalMinor: gift.targetAmountMinor,
                ),
              ),
            ),
    );
  }
}
