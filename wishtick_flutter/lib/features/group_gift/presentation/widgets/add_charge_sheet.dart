import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/sparkle_icon.dart';
import '../../domain/group_gift.dart';
import 'group_gift_widgets.dart';

/// What "Add a Charge" hands back.
typedef ChargeDraft = ({String label, int amountMinor});

/// "Add a Charge" (`4007:628`) — quick presets over a name/amount form.
///
/// A sheet rather than a route: it always returns to the charges list, and
/// pushing a page for two fields loses the list you are adding to.
Future<ChargeDraft?> showAddChargeSheet(
  BuildContext context, {
  GroupGiftCharge? existing,
}) {
  return showModalBottomSheet<ChargeDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddChargeSheet(existing: existing),
  );
}

class _AddChargeSheet extends StatefulWidget {
  const _AddChargeSheet({this.existing});

  /// When set, the sheet edits rather than adds.
  final GroupGiftCharge? existing;

  @override
  State<_AddChargeSheet> createState() => _AddChargeSheetState();
}

class _AddChargeSheetState extends State<_AddChargeSheet> {
  late final _name = TextEditingController(text: widget.existing?.label ?? '');
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : (widget.existing!.amountMinor ~/ 100).toString(),
  );

  int? _amountMinor;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _amountMinor = widget.existing?.amountMinor;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _name.text.trim().isNotEmpty && (_amountMinor ?? 0) > 0;

  void _pickPreset(String label) {
    setState(() => _name.text = label);
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(
      context,
    ).pop((label: _name.text.trim(), amountMinor: _amountMinor!));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      // Lifts the sheet clear of the keyboard — the amount field is the last
      // thing focused and would otherwise sit under it.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                _isEdit ? 'Edit Charge' : 'Add a Charge',
                style: context.text.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Presets are a shortcut for the *name* only — every charge still
            // needs an amount, which no preset can guess.
            Row(
              children: [
                SparkleIcon(size: AppSizes.iconMd, color: colors.textPrimary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Quick Charges',
                  style: context.text.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final preset in kQuickCharges)
                  _PresetChip(
                    label: preset.label,
                    icon: preset.icon,
                    selected:
                        _name.text.trim().toLowerCase() ==
                        preset.label.toLowerCase(),
                    onTap: () => _pickPreset(preset.label),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Custom Charge',
              style: context.text.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const GroupGiftFieldLabel('Charge Name', required: true),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 120,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) => null,
              decoration: const InputDecoration(hintText: 'Enter charge name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            const GroupGiftFieldLabel('Amount', required: true),
            const SizedBox(height: AppSpacing.sm),
            MoneyField(
              controller: _amount,
              hintText: 'Enter Amount',
              onChanged: (value) => setState(() => _amountMinor = value),
            ),

            const SizedBox(height: AppSpacing.section),
            ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              child: Text(_isEdit ? 'Save Charge' : 'Add Charge'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.primary : colors.optionFill,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AppSizes.iconMd,
                color: selected ? colors.onPrimary : colors.primaryMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: context.text.bodyMedium?.copyWith(
                  color: selected ? colors.onPrimary : colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
