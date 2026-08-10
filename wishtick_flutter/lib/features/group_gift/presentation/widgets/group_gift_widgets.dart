import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../domain/group_gift.dart';

/// A left-aligned section heading — "How should contributions be divided?",
/// "Added charges", "Selected Gifts (1)".
class GroupGiftSectionLabel extends StatelessWidget {
  const GroupGiftSectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: context.text.titleMedium?.copyWith(
        color: context.colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
    if (trailing == null) return label;
    return Row(
      children: [
        Expanded(child: label),
        trailing!,
      ],
    );
  }
}

/// A field label with the design's red required asterisk (`299:1658`,
/// `4007:628`).
class GroupGiftFieldLabel extends StatelessWidget {
  const GroupGiftFieldLabel(this.text, {this.required = false, super.key});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text.rich(
      TextSpan(
        text: text,
        style: context.text.bodyMedium?.copyWith(color: colors.textSecondary),
        children: required
            ? [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: colors.danger),
                ),
              ]
            : null,
      ),
    );
  }
}

/// A tappable rupee amount — the ₹500 / ₹1,000 / ₹2,000 chips (`299:1658`).
class AmountChip extends StatelessWidget {
  const AmountChip({
    required this.amountMinor,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final int amountMinor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.primary : colors.chipFill,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        // Deliberately not a Container with `alignment`. A Container that has
        // an alignment expands to its maximum *bounded* constraint, and a
        // Wrap hands children a maxWidth of the whole row — so every chip came
        // out full-bleed and stacked one per line. The Row hugs its content
        // instead, and centres the label vertically inside the tap target.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.chipHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatInrMinor(amountMinor),
                  style: context.text.bodyMedium?.copyWith(
                    color: selected ? colors.onPrimary : colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rupee input that reports whole rupees as minor units.
///
/// Digits only: a paise-accurate field invites "16999.00" and a stray decimal
/// point turns ₹16,999 into ₹169.99 silently. Every amount in the design is a
/// whole rupee, so the field only accepts those.
class MoneyField extends StatelessWidget {
  const MoneyField({
    required this.controller,
    required this.onChanged,
    this.hintText,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<int?> onChanged;
  final String? hintText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: context.text.titleMedium?.copyWith(
        color: colors.primary,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        prefixText: '₹',
        prefixStyle: context.text.titleMedium?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      onChanged: (raw) {
        final rupees = int.tryParse(raw);
        onChanged(rupees == null ? null : rupees * 100);
      },
    );
  }
}

/// The four presets on "Add a Charge" (`4007:628`), and the icons the charge
/// rows draw. Matched on the label so a charge typed by hand as "Delivery"
/// still gets the van rather than a generic tag.
const kQuickCharges = <({String label, IconData icon})>[
  (label: 'Delivery Charges', icon: Icons.local_shipping_outlined),
  (label: 'Packaging', icon: Icons.card_giftcard),
  (label: 'Handling Fee', icon: Icons.work_outline),
  (label: 'Platform Fee', icon: Icons.smartphone_outlined),
];

IconData chargeIconFor(String label) {
  final lower = label.toLowerCase();
  for (final preset in kQuickCharges) {
    // First word: "Delivery Charges" and a hand-typed "Delivery" should agree.
    if (lower.contains(preset.label.toLowerCase().split(' ').first)) {
      return preset.icon;
    }
  }
  return Icons.receipt_long_outlined;
}

/// One charge, as both the summary (read-only) and the charges screen (with
/// edit and delete) draw it.
class ChargeRow extends StatelessWidget {
  const ChargeRow({required this.charge, this.onEdit, this.onDelete, super.key});

  final GroupGiftCharge charge;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showActions = onEdit != null || onDelete != null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            decoration: BoxDecoration(
              color: colors.optionFill,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              chargeIconFor(charge.label),
              size: AppSizes.iconMd,
              color: colors.primaryMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  charge.label,
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (showActions)
                  Text(
                    formatInrMinor(charge.amountMinor),
                    style: context.text.bodyLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          if (!showActions)
            Text(
              formatInrMinor(charge.amountMinor),
              style: context.text.bodyLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              iconSize: AppSizes.iconMd,
              color: colors.textSecondary,
              tooltip: 'Edit ${charge.label}',
            ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              iconSize: AppSizes.iconMd,
              color: colors.danger,
              tooltip: 'Remove ${charge.label}',
            ),
        ],
      ),
    );
  }
}

/// One `label … amount` row of a cost breakdown.
class CostRow extends StatelessWidget {
  const CostRow({
    required this.label,
    required this.amountMinor,
    this.emphasised = false,
    super.key,
  });

  final String label;
  final int amountMinor;

  /// The Grand Total row — heavier, and the only one drawn in full ink.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = emphasised
        ? context.text.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          )
        : context.text.bodyLarge?.copyWith(color: colors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          // A long item title runs the full width, so without this the label
          // and the amount end up touching.
          const SizedBox(width: AppSpacing.md),
          Text(formatInrMinor(amountMinor), style: style),
        ],
      ),
    );
  }
}

/// The white card at the foot of the summary and charges screens:
/// Total Gift Price / Total Charges / Grand Total (`4006:463`, `4007:568`).
class CostSummaryCard extends StatelessWidget {
  const CostSummaryCard({
    required this.grandTotalMinor,
    this.giftsTotalMinor,
    this.chargesTotalMinor,
    super.key,
  });

  /// Omitted on the charges screen, which only breaks out the charges.
  final int? giftsTotalMinor;
  final int? chargesTotalMinor;
  final int grandTotalMinor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (giftsTotalMinor != null)
            CostRow(label: 'Total Gift Price', amountMinor: giftsTotalMinor!),
          if (chargesTotalMinor != null)
            CostRow(label: 'Total Charges', amountMinor: chargesTotalMinor!),
          CostRow(
            label: 'Grand Total',
            amountMinor: grandTotalMinor,
            emphasised: true,
          ),
        ],
      ),
    );
  }
}

/// A screen-foot action bar — the plum CTA every step of the flow ends with.
class GroupGiftFooter extends StatelessWidget {
  const GroupGiftFooter({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.child,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  /// Anything that sits above the button — the cost summary, an error.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (child != null) ...[child!, const SizedBox(height: AppSpacing.lg)],
            ElevatedButton(
              onPressed: busy ? null : onPressed,
              child: busy
                  ? SizedBox(
                      width: AppSizes.iconMd,
                      height: AppSizes.iconMd,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
