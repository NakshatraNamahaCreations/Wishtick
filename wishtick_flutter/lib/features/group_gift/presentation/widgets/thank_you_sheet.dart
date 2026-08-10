import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// Writes or edits the recipient's thank-you note.
///
/// ⚠️ **Not in the design.** `2219:603` and `2288:5` are both the read view of
/// the card; no composer was drawn. This is the smallest thing that makes the
/// card reachable — replace it when the real frame lands.
Future<String?> showThankYouSheet(
  BuildContext context, {
  String? existing,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ThankYouSheet(existing: existing),
  );
}

class _ThankYouSheet extends StatefulWidget {
  const _ThankYouSheet({this.existing});

  final String? existing;

  @override
  State<_ThankYouSheet> createState() => _ThankYouSheetState();
}

class _ThankYouSheetState extends State<_ThankYouSheet> {
  late final _note = TextEditingController(text: widget.existing ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final valid = _note.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
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
              'Your thank-you note',
              style: context.text.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Everyone who chipped in will see this.',
              style: context.text.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _note,
              autofocus: true,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    "Thank you all! I've wanted this for so long. You made my "
                    'birthday extra special.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: valid
                  ? () => Navigator.of(context).pop(_note.text.trim())
                  : null,
              child: const Text('Send thank you'),
            ),
          ],
        ),
      ),
    );
  }
}
