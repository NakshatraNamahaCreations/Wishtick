import 'package:confetti/confetti.dart';
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
class AllSetScreen extends ConsumerStatefulWidget {
  const AllSetScreen({super.key});

  @override
  ConsumerState<AllSetScreen> createState() => _AllSetScreenState();
}

class _AllSetScreenState extends ConsumerState<AllSetScreen> {
  late final ConfettiController _confetti = ConfettiController(
    duration: AppDurations.confettiBurst,
  );

  // Fires once, from here rather than initState: MediaQuery isn't reliably
  // available that early. The confetti package has no reduced-motion
  // awareness of its own (unlike WishtickSwipeButton's shimmer, which checks
  // this directly) — it just keeps scheduling frames indefinitely regardless
  // of `shouldLoop: false`, so skipping the burst here doubles as the fix for
  // a real accessibility setting and for a `pumpAndSettle` that would
  // otherwise never see the tree settle.
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduceMotion) _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      // Background inherits ThemeData.scaffoldBackgroundColor.
      body: SafeArea(
        child: Padding(
          // Horizontal 20 (not the usual 24) and a taller bottom margin —
          // both measured off the export (`199:145`): the button spans
          // 20..372 of the 393-wide frame, and sits 37px clear of the
          // bottom edge rather than the 24 every other margin here uses.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.huge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 4, not the body's own 3 — the export sits the mark closer
              // to the middle of the page than a straight 3:4 split gives.
              const Spacer(flex: 4),
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ConfettiWidget(
                      confettiController: _confetti,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      numberOfParticles: 28,
                      maxBlastForce: 18,
                      minBlastForce: 6,
                      gravity: 0.15,
                      // No token for a fifth hue (violet); reusing the plum
                      // primary for variety rather than reaching for a raw
                      // colour outside the palette layer.
                      colors: [
                        colors.celebration,
                        colors.info,
                        colors.accent,
                        colors.primaryMuted,
                        colors.primary,
                      ],
                    ),
                    // Bottom-aligned, not centred like the confetti: pins
                    // the image's own box edge to a known position so the
                    // gap below only has the asset's baked-in transparent
                    // margin to account for, not an unpredictable centring
                    // offset too.
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Image.asset(
                        'assets/logo/logo.png',
                        width: 160,
                        height: 160,
                      ),
                    ),
                  ],
                ),
              ),
              // No gap here at all: `logo.png` already carries ~40px of
              // transparent margin below the glyph itself at this render
              // size (see splash_screen.dart's _Mark) — that transparency
              // *is* the visible gap down to the headline, close to the
              // Figma-measured 24px on its own. Any further SizedBox here
              // would stack on top of it, not replace it.
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
