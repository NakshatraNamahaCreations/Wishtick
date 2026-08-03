import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_error_text.dart';
import '../../../../core/widgets/wishtick_swipe_button.dart';

/// The pinned footer under every selection step (Figma `36:839` etc.):
/// a "You Selected …" summary with "Clear all", then SKIP beside the plum
/// Continue pill with its gold check.
class SelectionFooter extends StatelessWidget {
  const SelectionFooter({
    required this.summary,
    required this.onContinue,
    required this.onSkip,
    this.onClearAll,
    this.onContinueSucceeded,
    this.continueLabel = 'Swipe to continue',
    this.busy = false,
    this.error,
    super.key,
  });

  /// The bold part after "You Selected " — e.g. `(2/2)` or a description.
  /// Null hides the summary row entirely.
  final String? summary;

  /// Does the real work behind the swipe. Return `true` to show the success
  /// check and go on to [onContinueSucceeded]; return `false` to spring back
  /// silently. Null renders the swipe track disabled.
  final Future<bool> Function()? onContinue;
  final VoidCallback onSkip;
  final VoidCallback? onClearAll;

  /// Called once the swipe's success check has been shown for a moment —
  /// this is where the caller navigates.
  final VoidCallback? onContinueSucceeded;

  /// The swipe track's caption. Defaults to the same prompt as every other
  /// Continue in the flow.
  final String continueLabel;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[
              WishtickErrorText(error!),
              const SizedBox(height: AppSpacing.md),
            ],
            if (summary != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: context.text.titleMedium?.copyWith(
                          color: colors.textPrimary,
                        ),
                        children: [
                          const TextSpan(text: 'You Selected '),
                          TextSpan(
                            text: summary,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onClearAll != null)
                    TextButton(
                      onPressed: onClearAll,
                      child: Text(
                        'Clear all',
                        style: context.text.labelMedium?.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: busy ? null : onSkip,
                    child: Text(
                      'SKIP',
                      style: context.text.labelLarge?.copyWith(
                        color: colors.celebration,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: WishtickSwipeButton(
                    label: continueLabel,
                    onSwiped: onContinue,
                    onSuccess: onContinueSucceeded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
