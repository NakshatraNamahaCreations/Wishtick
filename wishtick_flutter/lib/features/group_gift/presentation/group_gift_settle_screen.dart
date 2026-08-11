import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/currency.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/group_gift.dart';
import '../domain/settlement.dart';
import 'group_gift_controller.dart';
import 'settlement_controller.dart';
import 'widgets/group_gift_widgets.dart';
import 'widgets/share_upi_sheet.dart';

/// Settle up — every state of it.
///
/// One screen with three states rather than three screens, because which one
/// you get is decided entirely by the balance and whether the ledger has been
/// raised yet:
///
/// * surplus, no ledger → "Refund Distribution"    (`4093:444`)
/// * shortfall, no ledger → "Contribution Request" (`4092:174`)
/// * ledger raised → "Refund Progress"             (`4099:976`)
class GroupGiftSettleScreen extends ConsumerStatefulWidget {
  const GroupGiftSettleScreen({required this.groupGiftId, super.key});

  final String groupGiftId;

  @override
  ConsumerState<GroupGiftSettleScreen> createState() =>
      _GroupGiftSettleScreenState();
}

class _GroupGiftSettleScreenState extends ConsumerState<GroupGiftSettleScreen> {
  final _note = TextEditingController();
  final _amount = TextEditingController();

  int? _topUpMinor;
  bool _splitEqually = true;
  bool _primedTopUp = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      await ref
          .read(settlementProvider(widget.groupGiftId).notifier)
          .ensureLoaded();
      if (!mounted) return;
      unawaited(
        ref.read(groupGiftProvider(widget.groupGiftId).notifier).ensureLoaded(),
      );
      _primeTopUp();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  SettlementController get _controller =>
      ref.read(settlementProvider(widget.groupGiftId).notifier);

  /// Prefills the ask from the shortfall the balance already knows about.
  /// Only once — a host editing the figure must not have it overwritten.
  ///
  /// Never call this from `build`: writing to a [TextEditingController]
  /// notifies its listeners, which marks widgets dirty mid-build. Same reason
  /// the create screen primes its goal outside the build phase.
  void _primeTopUp() {
    if (_primedTopUp) return;
    final balance = ref.read(settlementProvider(widget.groupGiftId)).balance;
    if (balance == null || balance.differenceMinor >= 0) return;
    _primedTopUp = true;
    final shortfall = balance.absoluteDifferenceMinor;
    _amount.text = (shortfall ~/ 100).toString();
    setState(() => _topUpMinor = shortfall);
  }

  Future<void> _shareUpi(Settlement row) async {
    final result = await showShareUpiSheet(context);
    if (result == null || !mounted) return;
    await _controller.shareUpi(
      row.id,
      upiId: result.upiId,
      saveToProfile: result.saveToProfile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settlementProvider(widget.groupGiftId));
    final gift = ref.watch(groupGiftProvider(widget.groupGiftId)).gift;
    final me = ref.watch(sessionProvider).user?.id;
    final balance = state.balance;

    // Fires outside the build phase — see _primeTopUp.
    ref.listen(settlementProvider(widget.groupGiftId), (_, next) {
      if (next.balance != null) _primeTopUp();
    });

    return Scaffold(
      appBar: AppBar(title: Text(_title(state))),
      body: balance == null
          ? Center(
              child: state.error != null
                  ? WishtickErrorText(state.error!)
                  : const CircularProgressIndicator(),
            )
          : _body(state, balance, gift, me),
    );
  }

  String _title(SettlementState state) {
    if (state.hasLedger) {
      return state.settlements.first.direction ==
              SettlementDirection.returnToContributors
          ? 'Refund Progress'
          : 'Contribution Progress';
    }
    return switch (state.balance?.direction) {
      SettlementDirection.topUp => 'Contribution Request',
      SettlementDirection.returnToContributors => 'Refund Distribution',
      null => 'Settle Up',
    };
  }

  Widget _body(
    SettlementState state,
    GroupGiftBalance balance,
    GroupGift? gift,
    String? me,
  ) {
    if (state.hasLedger) return _progress(state, gift, me);
    return switch (balance.direction) {
      SettlementDirection.returnToContributors => _refundSetup(state, balance),
      SettlementDirection.topUp => _topUpSetup(state, balance),
      null => _square(balance),
    };
  }

  // ── Nothing owed ────────────────────────────────────────────────────────

  Widget _square(GroupGiftBalance balance) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: AppSizes.avatarLg,
            color: context.colors.payment,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Everyone is square.',
            style: context.text.titleMedium?.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${formatInrMinor(balance.collectedMinor)} collected against a '
            '${formatInrMinor(balance.totalCostMinor)} bill.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Surplus: "Refund Distribution" (`4093:444`) ─────────────────────────

  Widget _refundSetup(SettlementState state, GroupGiftBalance balance) {
    final each = balance.contributorCount == 0
        ? 0
        : balance.absoluteDifferenceMinor ~/ balance.contributorCount;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              _BalanceCard(
                leadLabel: 'Extra Balance',
                leadValue: formatInrMinor(balance.absoluteDifferenceMinor),
                trailLabel: 'Total Contributors',
                trailValue: '${balance.contributorCount}',
              ),
              const SizedBox(height: AppSpacing.xxl),
              const GroupGiftSectionLabel('Refund Method'),
              const SizedBox(height: AppSpacing.md),
              _MethodOption(
                title: 'Split equally',
                // The server does the real split, remainder paise and all —
                // this is the same arithmetic only to describe it.
                subtitle: 'Every one gets ${formatInrMinor(each)}',
                selected: _splitEqually,
                onTap: () => setState(() => _splitEqually = true),
              ),
              const SizedBox(height: AppSpacing.md),
              _MethodOption(
                title: 'Custom Refund',
                subtitle: 'Set the custom amount for each contributor',
                selected: !_splitEqually,
                onTap: () => setState(() => _splitEqually = false),
              ),
              if (!_splitEqually) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Per-person amounts are not editable yet — continuing will '
                  'split the balance equally.',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
              ],
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                WishtickErrorText(state.error!),
              ],
            ],
          ),
        ),
        GroupGiftFooter(
          label: 'Continue',
          busy: state.busy,
          onPressed: () => _controller.distributeReturn(),
        ),
      ],
    );
  }

  // ── Shortfall: "Contribution Request" (`4092:174`) ──────────────────────

  Widget _topUpSetup(SettlementState state, GroupGiftBalance balance) {
    final amount = _topUpMinor ?? 0;
    final each = balance.contributorCount == 0
        ? 0
        : amount ~/ balance.contributorCount;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              _RequestCard(amountMinor: amount, eachMinor: each),
              const SizedBox(height: AppSpacing.xl),
              // An input, not a read-out: the bill is frozen once anyone
              // contributes, so a shortfall only ever comes from the price
              // moving outside Wishtick — and only the host can see that.
              const GroupGiftFieldLabel(
                'Additional Amount Required',
                required: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              MoneyField(
                controller: _amount,
                onChanged: (value) => setState(() => _topUpMinor = value),
              ),
              const SizedBox(height: AppSpacing.xl),
              const GroupGiftFieldLabel('Message to group (optional)'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _note,
                maxLines: 4,
                maxLength: 280,
                textCapitalization: TextCapitalization.sentences,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      required maxLength,
                    }) => null,
                decoration: const InputDecoration(
                  hintText: 'The gift price has increased a bit.',
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                WishtickErrorText(state.error!),
              ],
            ],
          ),
        ),
        GroupGiftFooter(
          label: 'Send Request',
          busy: state.busy,
          onPressed: amount <= 0
              ? null
              : () => _controller.requestTopUp(
                  additionalAmountMinor: amount,
                  note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                ),
        ),
      ],
    );
  }

  // ── Ledger raised: "Refund Progress" (`4099:976`) ───────────────────────

  Widget _progress(SettlementState state, GroupGift? gift, String? me) {
    final isReturn =
        state.settlements.first.direction ==
        SettlementDirection.returnToContributors;
    final names = {
      for (final p in gift?.participants ?? const []) p.userId: p.name,
    };
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _InfoBanner(
            text: isReturn
                ? 'Refunds are sent outside Wishtick. Once sent, mark each '
                      'one as "Sent".'
                : 'Contributions are paid outside Wishtick. Once you have '
                      'paid, mark yours as "Sent".',
          ),
          const SizedBox(height: AppSpacing.md),
          const _InfoBanner(text: 'Everyone involved will be notified.'),
          const SizedBox(height: AppSpacing.xxl),
          GroupGiftSectionLabel(
            isReturn
                ? 'Contributors (${state.settlements.length})'
                : 'Members (${state.settlements.length})',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final row in state.settlements)
            _SettlementRow(
              row: row,
              name: names[row.counterpartId(me ?? '')] ?? 'A friend',
              isHost: row.counterpartId(me ?? '') == gift?.hostId,
              amPayer: me != null && row.amPayer(me),
              busy: state.busy,
              onShareUpi: () => _shareUpi(row),
              onMarkSent: () => _controller.markSent(row.id),
              onConfirm: () => _controller.confirmReceived(row.id),
            ),
          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            WishtickErrorText(state.error!),
          ],
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.leadLabel,
    required this.leadValue,
    required this.trailLabel,
    required this.trailValue,
  });

  final String leadLabel;
  final String leadValue;
  final String trailLabel;
  final String trailValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.paymentSubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leadLabel,
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  leadValue,
                  style: context.text.titleLarge?.copyWith(
                    color: colors.payment,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trailLabel,
                style: context.text.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                trailValue,
                style: context.text.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.amountMinor, required this.eachMinor});

  final int amountMinor;
  final int eachMinor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.paymentSubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Text(
            'Additional Amount Required',
            style: context.text.bodyLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatInrMinor(amountMinor),
            style: context.text.headlineSmall?.copyWith(
              color: colors.payment,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Each Member needs to add',
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatInrMinor(eachMinor),
            style: context.text.titleLarge?.copyWith(
              color: colors.payment,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.surfaceAlt : colors.background,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? colors.primary : colors.border,
                size: AppSizes.iconLg,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.bodyLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: AppSizes.iconMd,
            color: colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Width of a ledger row's trailing control, measured off `4099:976`. Wide
/// enough for "Mark as Sent" without wrapping.
const _actionWidth = 136.0;

/// One ledger row. Which control it offers depends on which side of the
/// payment the viewer is on — the payer marks it sent, the receiver shares a
/// UPI ID and confirms arrival.
class _SettlementRow extends StatelessWidget {
  const _SettlementRow({
    required this.row,
    required this.name,
    required this.isHost,
    required this.amPayer,
    required this.busy,
    required this.onShareUpi,
    required this.onMarkSent,
    required this.onConfirm,
  });

  final Settlement row;
  final String name;
  final bool isHost;
  final bool amPayer;
  final bool busy;
  final VoidCallback onShareUpi;
  final VoidCallback onMarkSent;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: AppSizes.avatarSm / 2,
            backgroundColor: colors.optionFill,
            child: Text(
              name.characters.first.toUpperCase(),
              style: context.text.bodyMedium?.copyWith(
                color: colors.primaryMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          'Host',
                          style: context.text.bodySmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  formatInrMinor(row.amountMinor),
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Bounded on purpose. The button theme sets `minimumSize:
          // Size.fromHeight(...)`, which is `Size(double.infinity, h)` — an
          // infinite *minimum* width. That is what makes footer buttons
          // full-bleed, and it is why one dropped into a Row's unbounded slot
          // asserts instead of rendering. Measured off `4099:976`.
          SizedBox(width: _actionWidth, child: _action(context)),
        ],
      ),
    );
  }

  Widget _action(BuildContext context) {
    final colors = context.colors;

    if (row.status == SettlementStatus.confirmed) {
      return _Pill(label: 'Settled', color: colors.payment);
    }
    if (row.status == SettlementStatus.cancelled) {
      return _Pill(label: 'Cancelled', color: colors.textMuted);
    }

    if (amPayer) {
      // Nowhere to send it yet — the server refuses "sent" without a UPI ID,
      // so the button says what is actually missing.
      if (row.upiId == null) {
        return _Pill(label: 'Awaiting UPI ID', color: colors.textMuted);
      }
      if (row.status == SettlementStatus.sent) {
        return _Pill(label: 'Sent', color: colors.payment);
      }
      return OutlinedButton(
        onPressed: busy ? null : onMarkSent,
        child: const Text('Mark as Sent'),
      );
    }

    // Receiver's side.
    if (row.upiId == null) {
      return OutlinedButton(
        onPressed: busy ? null : onShareUpi,
        child: const Text('Share UPI ID'),
      );
    }
    return OutlinedButton(
      onPressed: busy ? null : onConfirm,
      child: Text(row.status == SettlementStatus.sent ? 'Confirm' : 'Received'),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.paymentSubtle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: context.text.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
