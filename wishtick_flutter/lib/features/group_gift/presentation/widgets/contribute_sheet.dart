import 'package:flutter/material.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import 'group_gift_widgets.dart';

/// What the contribute sheet hands back.
typedef ContributionDraft = ({int amountMinor, String? message});

/// "Contribute" (`316:119`).
///
/// A *pledge*, not a payment — Wishtick never holds the money. The button says
/// "Pay ₹2000" because that is what the member is about to do, on their own
/// UPI app, into the host's account.
/// Takes the chips rather than the whole gift: an invitee pays from the
/// invitation screen, before they are a member and before they can read the
/// group at all, and the chips are the only thing this sheet ever needed.
Future<ContributionDraft?> showContributeSheet(
  BuildContext context, {
  required List<int> suggestedAmountsMinor,
}) {
  return showModalBottomSheet<ContributionDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _ContributeSheet(suggestedAmountsMinor: suggestedAmountsMinor),
  );
}

class _ContributeSheet extends StatefulWidget {
  const _ContributeSheet({required this.suggestedAmountsMinor});

  final List<int> suggestedAmountsMinor;

  @override
  State<_ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends State<_ContributeSheet> {
  final _custom = TextEditingController();
  final _message = TextEditingController();

  int? _selected;
  int? _customMinor;

  /// The custom field wins when it has a value — typing after tapping a chip
  /// should change the amount, not be silently ignored.
  int? get _amountMinor => _customMinor ?? _selected;

  @override
  void dispose() {
    _custom.dispose();
    _message.dispose();
    super.dispose();
  }

  void _pick(int amountMinor) {
    setState(() {
      _selected = amountMinor;
      _custom.clear();
      _customMinor = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = _amountMinor;
    final chips = widget.suggestedAmountsMinor;

    return Padding(
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
                'Contribute',
                style: context.text.titleLarge?.copyWith(
                  color: context.headlineBrandColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            if (chips.isNotEmpty) ...[
              Text(
                'Suggested Contribution',
                style: context.text.titleSmall?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final chip in chips)
                    AmountChip(
                      amountMinor: chip,
                      selected: _selected == chip && _customMinor == null,
                      onTap: () => _pick(chip),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            Text(
              'Custom Amount',
              style: context.text.titleSmall?.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            MoneyField(
              controller: _custom,
              hintText: 'Enter Custom Amount',
              onChanged: (value) => setState(() {
                _customMinor = value;
                if (value != null) _selected = null;
              }),
            ),

            const SizedBox(height: AppSpacing.xl),
            Text(
              'Your Message (Optional)',
              style: context.text.titleSmall?.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _message,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 280,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) => null,
              decoration: const InputDecoration(hintText: 'Happy Birthday!'),
            ),

            const SizedBox(height: AppSpacing.section),
            ElevatedButton(
              onPressed: (amount ?? 0) <= 0
                  ? null
                  : () {
                      final text = _message.text.trim();
                      Navigator.of(context).pop((
                        amountMinor: amount!,
                        message: text.isEmpty ? null : text,
                      ));
                    },
              child: Text(
                amount == null ? 'Pay' : 'Pay ${formatInrMinor(amount)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
