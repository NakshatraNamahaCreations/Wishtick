import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// A bold label with a red asterisk when required, above a filled input —
/// the form pattern used throughout onboarding (Figma `31:608`).
class LabelledField extends StatelessWidget {
  const LabelledField({
    required this.label,
    required this.child,
    this.required = false,
    this.errorText,
    super.key,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: context.text.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(text: label),
              if (required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: colors.danger),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: context.text.bodySmall?.copyWith(color: colors.danger),
          ),
        ],
      ],
    );
  }
}
