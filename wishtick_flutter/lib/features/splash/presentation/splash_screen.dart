import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../auth/presentation/session_controller.dart';
import 'particle_text.dart';

/// Splash — Figma `143:356`.
///
/// Centred mark, wordmark, tagline, then a determinate progress bar with the
/// "Setting up your celebrations" caption pinned near the bottom.
///
/// The stored session is resolved once the progress bar finishes rather than
/// immediately, so the brand moment always plays in full; the router's redirect
/// takes over as soon as the session lands.
///
/// **This screen does not follow the theme.** It paints
/// `gradients.splash` — the same plum wash in light and dark — because the
/// splash is a brand moment rather than a page. Every foreground here is
/// therefore drawn in [WishtickColors.textOnDark], the token whose job is to
/// stay legible on a dark surface in *both* themes; reaching for
/// `colors.primary` or `colors.textSecondary` would render plum-on-plum and
/// near-invisible grey respectively under the light theme.
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

  /// The entrance choreography rides the *same* controller as the progress
  /// bar rather than a second one, so the whole sequence is guaranteed to
  /// finish before [_onDone] routes away — a separate timeline could outrun
  /// the redirect and get cut off mid-flip on a fast restore.
  ///
  /// The mark flips in first, then the wordmark and tagline assemble under it.
  ///
  /// Fractions of [AppDurations.splash] (4s), so the wall-clock windows are:
  /// mark 0–900ms, wordmark 900–2500ms, tagline 1300–2900ms. That leaves the
  /// finished lock-up on screen for over a second before the redirect.
  ///
  /// The two text stages run 1.6s each — deliberately long, because particles
  /// converging is a slower read than a fade and looks rushed under about a
  /// second. The flip keeps its original 900ms; it is a simple turn and
  /// stretching it only makes the mark hang.
  late final CurvedAnimation _flip = _stage(0.000, 0.225);
  late final CurvedAnimation _wordmark = _stage(0.225, 0.625);
  late final CurvedAnimation _tagline = _stage(0.325, 0.725);

  late final List<CurvedAnimation> _stages = [_flip, _wordmark, _tagline];

  CurvedAnimation _stage(
    double begin,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: curve),
    );
  }

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
    // Each stage registers a status listener on the controller; dropping them
    // before the controller goes keeps that off the leak reports.
    for (final stage in _stages) {
      stage.dispose();
    }
    _controller
      ..removeStatusListener(_onDone)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Ivory in both themes — see the class doc for why nothing here reads a
    // theme-varying token.
    final onSplash = colors.textOnDark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The backdrop is dark whichever theme is active, so the status-bar
      // icons must be light in both. Without this the light theme draws them
      // dark — the app-bar default — on top of near-black plum.
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: context.gradients.splash),
        child: Scaffold(
          // Transparent so the gradient above shows through; otherwise the
          // scaffold paints WishtickColors.background over it.
          backgroundColor: Colors.transparent,
          body: SafeArea(
            // A Scaffold body gets *loose* width constraints, and every child of
            // this Column is intrinsic-width — without forcing full width the
            // Column shrinks to its widest text and hugs the left edge on device.
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _FlipIn(animation: _flip, child: _Mark()),
                  const SizedBox(height: AppSpacing.lg),
                  ParticleText(
                    text: 'Wishtick',
                    style: AppTypography.displayMedium.copyWith(
                      color: onSplash,
                    ),
                    animation: _wordmark,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ParticleText(
                    text: 'Gifting, made together',
                    style: (context.text.bodyLarge ?? const TextStyle())
                        .copyWith(color: onSplash),
                    animation: _tagline,
                    // A different cloud from the wordmark's — with the same
                    // seed the two lines scatter in visibly parallel paths.
                    seed: 1,
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
                          // The export shows the bar at 100%, so it records no
                          // track colour. A dimmed ivory reads as a groove on
                          // the wash while the fill is still travelling.
                          backgroundColor: onSplash.withValues(alpha: 0.24),
                          valueColor: AlwaysStoppedAnimation(onSplash),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Setting up your celebrations',
                    style: context.text.bodyMedium?.copyWith(color: onSplash),
                  ),
                  const SizedBox(height: AppSpacing.huge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Flips [child] face-on around its vertical axis as [animation] runs.
///
/// The mark starts back-facing at −180° and lands square at 0°. It fades in
/// over the first third of the turn rather than at the end: at −180° the glyph
/// is fully readable but mirrored, and popping that in would look like a
/// mistake rather than a reveal.
///
/// Honours the platform "reduce motion" setting — with it on the mark is drawn
/// square and opaque from the first frame, since a spinning logo is exactly the
/// kind of vestibular trigger that setting exists to suppress.
class _FlipIn extends StatelessWidget {
  const _FlipIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  /// Depth of the perspective divide. Large enough to read as a turn in space
  /// rather than a horizontal squash; small enough not to fish-eye the mark.
  static const _perspective = 0.0012;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return AnimatedBuilder(
      animation: animation,
      // The mark is a static image — built once and passed through, not
      // rebuilt on every one of the ~54 frames this turn takes.
      child: child,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: Curves.easeIn.transform(math.min(1, t * 3)),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, _perspective)
              ..rotateY(-math.pi * (1 - t)),
            child: child,
          ),
        );
      },
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
