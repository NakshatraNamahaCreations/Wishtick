import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../auth/presentation/session_controller.dart';

/// Splash — Figma `143:356`.
///
/// Centred mark, wordmark, tagline, then a determinate progress bar with the
/// "Setting up your celebrations" caption pinned near the bottom.
///
/// The stored session is resolved once the progress bar finishes rather than
/// immediately, so the brand moment always plays in full; the router's redirect
/// takes over as soon as the session lands.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.splash,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _controller.addStatusListener(_onDone);
  }

  void _onDone(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    // Resolving the session flips it off `unknown`, which fires the router's
    // refreshListenable and redirects to home or the welcome flow.
    unawaited(ref.read(sessionProvider.notifier).restore());
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onDone)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      // Background inherits ThemeData.scaffoldBackgroundColor — see WishtickColors.background.
      body: SafeArea(
        // A Scaffold body gets *loose* width constraints, and every child of
        // this Column is intrinsic-width — without forcing full width the
        // Column shrinks to its widest text and hugs the left edge on device.
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              const Spacer(flex: 3),
              _Mark(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Wishtick',
                style: AppTypography.displayMedium.copyWith(
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Gifting, made together',
                style: context.text.bodyLarge?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: 131,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => LinearProgressIndicator(
                      value: _controller.value,
                      minHeight: 4,
                      backgroundColor: colors.border,
                      valueColor: AlwaysStoppedAnimation(colors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Setting up your celebrations',
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Figma logo mark (`214:607`) — the gradient heart-and-check exported to
/// `assets/logo/logo.png`, floating directly on the background with no
/// backdrop, matching the export.
///
/// 150 rather than the file's own 165 canvas: the source PNG carries a
/// transparent margin around the glyph (a soft drop-shadow falloff), so
/// displaying it at its raw canvas size undershoots the reference — sized
/// here so the *visible* heart measures the same ~91×81 the reference export
/// shows in a 393-wide frame.
class _Mark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/logo/logo.png', width: 150, height: 150);
  }
}
