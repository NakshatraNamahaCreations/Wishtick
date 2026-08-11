import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

typedef UpiDraft = ({String upiId, bool saveToProfile});

/// "Enter UPI ID" (`4095:611`).
///
/// Only the person being paid ever sees this — the server refuses a UPI ID
/// from anyone else, so nobody can redirect someone else's money.
Future<UpiDraft?> showShareUpiSheet(
  BuildContext context, {
  String? initialUpiId,
}) {
  return showModalBottomSheet<UpiDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ShareUpiSheet(initialUpiId: initialUpiId),
  );
}

class _ShareUpiSheet extends StatefulWidget {
  const _ShareUpiSheet({this.initialUpiId});

  final String? initialUpiId;

  @override
  State<_ShareUpiSheet> createState() => _ShareUpiSheetState();
}

class _ShareUpiSheetState extends State<_ShareUpiSheet> {
  late final _upi = TextEditingController(text: widget.initialUpiId ?? '');

  /// Pre-ticked, as the design shows it. Saving only affects the *default*
  /// offered next time — every settlement still snapshots its own copy, so
  /// editing the profile later cannot redirect a payment already in flight.
  bool _save = true;

  @override
  void dispose() {
    _upi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final valid = _upi.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter UPI ID',
              style: context.text.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _upi,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              decoration: const InputDecoration(hintText: 'Enter your UPI ID'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xxl),
            InkWell(
              onTap: () => setState(() => _save = !_save),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _save,
                    onChanged: (v) => setState(() => _save = v ?? false),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Save this UPI ID in my profile',
                          style: context.text.bodyLarge?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'For faster refunds in the future.',
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
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton(
              onPressed: !valid
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop((upiId: _upi.text.trim(), saveToProfile: _save)),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
