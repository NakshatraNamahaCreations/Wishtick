import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// How the host wants to make the invitation (`2248:5`).
enum InviteMethod { template, upload }

Future<InviteMethod?> showInviteMethodSheet(BuildContext context) {
  return showModalBottomSheet<InviteMethod>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _InviteMethodSheet(),
  );
}

class _InviteMethodSheet extends StatelessWidget {
  const _InviteMethodSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
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
              'How would you like to\ncreate your invitation?',
              textAlign: TextAlign.center,
              style: context.text.titleLarge?.copyWith(
                color: context.headlineBrandColor,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choose an option that works best for you',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _MethodCard(
              icon: Icons.dashboard_customize_outlined,
              title: 'Use Wishtick Templates',
              blurb: 'Choose from beautifully designed invitation templates.',
              onTap: () =>
                  Navigator.of(context).pop(InviteMethod.template),
            ),
            const SizedBox(height: AppSpacing.lg),
            _MethodCard(
              icon: Icons.cloud_upload_outlined,
              title: 'Upload Your Own Invitation',
              blurb: 'Already have a design upload it and share it with your '
                  'guests.',
              onTap: () => Navigator.of(context).pop(InviteMethod.upload),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: AppSizes.iconMd,
                  color: colors.textMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'You can preview and edit details before sending.',
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
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

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.blurb,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String blurb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.optionFill,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  size: AppSizes.iconLg,
                  color: colors.primaryMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.titleSmall?.copyWith(
                        color: context.headlineBrandColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      blurb,
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
