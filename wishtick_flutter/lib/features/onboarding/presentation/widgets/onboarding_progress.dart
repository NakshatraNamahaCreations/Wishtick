import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// Locates the progress heart's [CustomPaint] in tests, since the widget
/// that owns it is private — reading the painter's fields directly is more
/// robust than sampling rendered pixels.
@visibleForTesting
const progressHeartKey = ValueKey<String>('onboardingProgressHeart');

/// The onboarding progress header — Figma `31:608`.
///
/// An outlined heart at the start, a filled heart at the end, a gold track
/// between them, and a "Step N of 5" caption underneath.
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    required this.step,
    required this.totalSteps,
    super.key,
  });

  /// 1-based.
  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The bar shows *position*: how far through the 5 steps you are, so it is
    // already at 4/5 while you are working on step 4. The heart shows *steps
    // actually completed* — one less, so it never reaches full until the
    // whole flow is done, which this component never shows on its own.
    final barFraction = (step / totalSteps).clamp(0.0, 1.0);
    final heartFraction = ((step - 1) / totalSteps).clamp(0.0, 1.0);

    return Semantics(
      label: 'Step $step of $totalSteps',
      child: Column(
        children: [
          Row(
            children: [
              _ProgressHeart(fraction: heartFraction),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: barFraction,
                    minHeight: 4,
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation(colors.celebration),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const _BrandHeart(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Step $step of $totalSteps',
            style: context.text.titleSmall?.copyWith(
              color: colors.celebration,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The heart that opens the progress track, reddening as steps complete —
/// one fifth per step, capped short of full until the whole flow finishes.
///
/// A heart's ink is almost entirely in its lower body, with only a thin
/// notch near the top — a plain height-crop reveals the whole heart well
/// before the fraction reaches 1, and a plain opacity fade isn't much
/// better, since a saturated red still reads as "basically red" at well
/// under full alpha. Both were tried and both looked wrong. This crops by
/// height like the first attempt, but the crop line is looked up from
/// [HeartFillGeometry], which samples the heart's own path once to find how
/// much *height* corresponds to how much *area* — so revealed area actually
/// matches the fraction, rather than either guess.
class _ProgressHeart extends StatelessWidget {
  const _ProgressHeart({required this.fraction});

  /// 0 to 1.
  final double fraction;

  /// Sized on its own rather than [AppSizes.iconLg] — that token is shared by
  /// icons across the app (back buttons, the camera badge, …), and this
  /// heart needed to shrink without pulling those along with it.
  static const _size = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: fraction.clamp(0.0, 1.0)),
      duration: AppDurations.slow,
      curve: Curves.easeOut,
      builder: (context, value, _) => CustomPaint(
        key: progressHeartKey,
        size: const Size(_size, _size),
        painter: HeartPainter(
          revealHeight: HeartFillGeometry.heightFractionForArea(value),
          outlineColor: colors.primary,
          fillColor: colors.heartFill,
        ),
      ),
    );
  }
}

/// Both the outline and the fill are drawn from the *same* [_heartPath], so
/// they nest exactly — stacking two separately-authored Material glyphs
/// (`favorite_border` under a cropped `favorite`) risked the crop line
/// disagreeing with the outline it sat inside.
///
/// Public, like [HeartFillGeometry], only so tests can read [revealHeight]
/// and [fillColor] straight off the painter instead of sampling pixels.
@visibleForTesting
class HeartPainter extends CustomPainter {
  const HeartPainter({
    required this.revealHeight,
    required this.outlineColor,
    required this.fillColor,
  });

  /// Height fraction (0 to 1) to reveal from the bottom — already corrected
  /// for area by the caller, not a raw step fraction.
  final double revealHeight;
  final Color outlineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _heartPath(size.width);

    canvas.drawPath(
      path,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.09,
    );

    if (revealHeight <= 0) return;
    canvas.save();
    final revealed = size.height * revealHeight;
    canvas.clipRect(
      Rect.fromLTWH(0, size.height - revealed, size.width, revealed),
    );
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HeartPainter oldDelegate) =>
      oldDelegate.revealHeight != revealHeight ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.fillColor != fillColor;
}

/// A heart traced in a 100×100 box: wide lobes near the top, tapering to a
/// point at the bottom — deliberately the same control points reviewed in
/// the fill-technique comparison before this was implemented, so what
/// shipped matches what was picked.
Path _heartPath(double size) {
  final s = size / 100;
  double x(double v) => v * s;
  double y(double v) => v * s;

  return Path()
    ..moveTo(x(50), y(88))
    ..cubicTo(x(15), y(62), x(0), y(42), x(0), y(25))
    ..cubicTo(x(0), y(10), x(12), y(0), x(26), y(0))
    ..cubicTo(x(36), y(0), x(46), y(7), x(50), y(20))
    ..cubicTo(x(54), y(7), x(64), y(0), x(74), y(0))
    ..cubicTo(x(88), y(0), x(100), y(10), x(100), y(25))
    ..cubicTo(x(100), y(42), x(85), y(62), x(50), y(88))
    ..close();
}

/// The heart's area-vs-height correspondence, sampled once from the actual
/// path rather than assumed — an eyeballed crop is exactly what produced the
/// original bug (see [_ProgressHeart]'s doc comment).
///
/// Public (rather than library-private like the rest of this file) purely so
/// tests can verify the calibration math directly instead of only through
/// rendered pixels.
@visibleForTesting
abstract final class HeartFillGeometry {
  static const _resolution = 100;
  static List<double>? _cumulativeAreaFromBottom;

  static List<double> get _table {
    final cached = _cumulativeAreaFromBottom;
    if (cached != null) return cached;

    final path = _heartPath(_resolution.toDouble());
    final rowCounts = List<int>.filled(_resolution, 0);
    for (var row = 0; row < _resolution; row++) {
      var count = 0;
      for (var col = 0; col < _resolution; col++) {
        if (path.contains(Offset(col + 0.5, row + 0.5))) count++;
      }
      rowCounts[row] = count;
    }
    final total = rowCounts.fold<int>(0, (a, b) => a + b);

    final table = List<double>.filled(_resolution + 1, 0);
    var running = 0;
    for (
      var rowsFromBottom = 1;
      rowsFromBottom <= _resolution;
      rowsFromBottom++
    ) {
      running += rowCounts[_resolution - rowsFromBottom];
      table[rowsFromBottom] = total > 0 ? running / total : 0;
    }
    return _cumulativeAreaFromBottom = table;
  }

  /// Height fraction (0 to 1, measured from the bottom) that reveals
  /// [areaFraction] of the heart's total area.
  static double heightFractionForArea(double areaFraction) {
    final table = _table;
    for (
      var rowsFromBottom = 0;
      rowsFromBottom <= _resolution;
      rowsFromBottom++
    ) {
      if (table[rowsFromBottom] >= areaFraction) {
        return rowsFromBottom / _resolution;
      }
    }
    return 1.0;
  }
}

/// The Wishtick mark that closes the progress track — the same gradient
/// heart-and-check exported to `assets/logo/logo.png`, sized down to match
/// the outline heart at the other end of the track. A fixed brand asset, so
/// it does not follow the light/dark token swap the rest of the screen does.
class _BrandHeart extends StatelessWidget {
  const _BrandHeart();

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/logo/logo.png', width: 40, height: 40);
  }
}
