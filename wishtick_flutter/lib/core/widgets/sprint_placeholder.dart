import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/theme_extensions.dart';

/// Stands in for a screen that a later sprint will build.
///
/// It names the sprint and the Figma node so the placeholder itself tells you
/// where the design lives. Delete each usage as its sprint lands.
class SprintPlaceholder extends StatelessWidget {
  const SprintPlaceholder({
    required this.title,
    required this.sprint,
    required this.figmaNodeId,
    super.key,
  });

  final String title;
  final String sprint;
  final String figmaNodeId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      // Background inherits ThemeData.scaffoldBackgroundColor — see WishtickColors.background.
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.design_services_outlined,
                size: 48,
                color: colors.textMuted,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: context.text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Lands in $sprint',
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Figma $figmaNodeId',
                style: context.text.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
