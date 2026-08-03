import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../auth/presentation/session_controller.dart';

/// "You're all set!" — Figma `199:145`.
///
/// Confetti-framed heart mark, serif headline, supporting copy, and the
/// full-width "Explore Wishtick" pill. Tapping it marks onboarding complete;
/// the router's redirect then lands on Home.
class AllSetScreen extends ConsumerWidget {
  const AllSetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Scaffold(
      // Background inherits ThemeData.scaffoldBackgroundColor.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              // The design's confetti heart mark is not exported yet; the
              // brand heart stands in at the same size.
              Icon(Icons.favorite, size: 96, color: colors.accent),
              const SizedBox(height: AppSpacing.xxxl),
              Text(
                "You're all set!",
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium.copyWith(
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your profile is complete and ready to make gifting amazing.',
                textAlign: TextAlign.center,
                style: context.text.bodyLarge?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(flex: 4),
              ElevatedButton(
                onPressed: () =>
                    ref.read(sessionProvider.notifier).markOnboardingComplete(),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Explore Wishtick'),
                    SizedBox(width: AppSpacing.sm),
                    Icon(Icons.chevron_right, size: AppSizes.iconLg),
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
