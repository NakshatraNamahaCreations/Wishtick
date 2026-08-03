import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import 'onboarding_progress.dart';

/// The chrome every onboarding step shares (Figma `36:839`, `39:1061`,
/// `51:42`, `199:10`): circular back button, hearts progress header, serif
/// headline, muted subtitle, scrollable body, and a pinned footer.
class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    required this.step,
    required this.headline,
    required this.subtitle,
    required this.body,
    required this.footer,
    this.onBack,
    super.key,
  });

  /// 1-based position shown as "Step N of 5".
  final int step;
  final String headline;
  final String subtitle;
  final Widget body;
  final Widget footer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      // Background inherits ThemeData.scaffoldBackgroundColor.
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  // stretch, not start: this is what hands [body] a *tight*
                  // width. Under start every injected step body would be laid
                  // out loose and any child sized only by height would shrink
                  // to its content — the bug that hit the Continue pill.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.md),
                          _CircleBack(onPressed: onBack ?? () => context.pop()),
                          const SizedBox(height: AppSpacing.xl),
                          OnboardingProgress(step: step, totalSteps: 5),
                          const SizedBox(height: AppSpacing.xxl),
                          Text(
                            headline,
                            style: AppTypography.displaySmall.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            subtitle,
                            style: context.text.bodyLarge?.copyWith(
                              color: colors.primaryMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
                    body,
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
            footer,
          ],
        ),
      ),
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: colors.surface,
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.chevron_left, size: AppSizes.iconLg),
          color: colors.textPrimary,
          tooltip: 'Back',
        ),
      ),
    );
  }
}
