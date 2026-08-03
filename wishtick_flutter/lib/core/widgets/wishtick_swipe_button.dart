import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/theme_extensions.dart';

enum _Phase { idle, dragging, processing, success }

/// The plum "swipe to continue" pill used across onboarding — Figma `31:608`,
/// `195:131`.
///
/// A white-on-gold arrow sits inside the left edge; drag it to the far end to
/// confirm. On commit the track collapses into a circle centred on the
/// button, which shows a spinner while [onSwiped] runs and a check once it
/// succeeds — then
/// [onSuccess] fires (that is where the caller navigates, so the user
/// actually sees the confirmation before the screen changes, rather than the
/// track resetting mid-flight while the destination is still loading).
///
/// A drag that stops short of the commit threshold, or an [onSwiped] that
/// resolves `false`, springs the track back to idle with no visible failure
/// state — the screen is expected to explain why elsewhere (field errors, an
/// error banner).
///
/// The shimmer stops when the platform asks for reduced motion, which also
/// keeps `pumpAndSettle` from spinning forever in tests — a perpetually
/// repeating animation never lets the tree settle.
class WishtickSwipeButton extends StatefulWidget {
  const WishtickSwipeButton({
    required this.onSwiped,
    this.onSuccess,
    this.label = 'Swipe to continue',
    super.key,
  });

  /// Does the real work. Return `true` to show the success check and go on to
  /// [onSuccess]; return `false` to spring back silently.
  ///
  /// Null renders the track disabled and refuses the drag.
  final Future<bool> Function()? onSwiped;

  /// Called once the success check has been shown for a moment.
  final VoidCallback? onSuccess;

  final String label;

  @override
  State<WishtickSwipeButton> createState() => _WishtickSwipeButtonState();
}

class _WishtickSwipeButtonState extends State<WishtickSwipeButton>
    with TickerProviderStateMixin {
  /// Ø32 with an equal margin all round, measured off the frame exports.
  static const _knobSize = 32.0;
  static const _inset = (AppSizes.buttonHeight - _knobSize) / 2;

  /// How far along the track counts as "committed" on release.
  static const _completeAt = 0.75;

  /// A flick this fast completes even from short of [_completeAt].
  static const _flingVelocity = 800.0;

  /// Position of the knob while idle/dragging, 0 (start) to 1 (end of travel).
  late final AnimationController _knob = AnimationController(
    vsync: this,
    duration: AppDurations.normal,
  );

  /// 0 (full track) to 1 (collapsed to a circle), driven only once committed.
  late final AnimationController _collapse = AnimationController(
    vsync: this,
    duration: AppDurations.normal,
  );

  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: AppDurations.shimmer,
  );

  _Phase _phase = _Phase.idle;
  bool _shimmerRunning = false;

  @override
  void dispose() {
    _knob.dispose();
    _collapse.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  void _syncShimmer({required bool wanted}) {
    if (wanted == _shimmerRunning) return;
    _shimmerRunning = wanted;
    if (wanted) {
      _shimmer.repeat();
    } else {
      _shimmer.stop();
      _shimmer.value = 0;
    }
  }

  void _onDragUpdate(DragUpdateDetails details, double travel) {
    // Ignored rather than unreachable: the GestureDetector's callbacks stay
    // registered for the whole widget lifetime (see the comment in [build]),
    // so a stray event can still arrive once a swipe has committed.
    if (_phase == _Phase.processing || _phase == _Phase.success) return;
    if (travel <= 0) return;
    if (_phase != _Phase.dragging) setState(() => _phase = _Phase.dragging);
    _knob.value = (_knob.value + details.primaryDelta! / travel).clamp(
      0.0,
      1.0,
    );
  }

  void _onDragEnd(DragEndDetails details) {
    if (_phase == _Phase.processing || _phase == _Phase.success) return;
    final flung = (details.primaryVelocity ?? 0) > _flingVelocity;
    if (_knob.value >= _completeAt || flung) {
      unawaited(_commit());
    } else {
      unawaited(
        _knob.animateTo(0, curve: Curves.easeOut).then((_) {
          if (mounted) setState(() => _phase = _Phase.idle);
        }),
      );
    }
  }

  /// Runs the whole commit lifecycle: collapse → await the caller's work →
  /// check-and-dwell or silent spring-back. Reachable from a completed drag
  /// or, for assistive tech, straight from a semantic tap.
  Future<void> _commit() async {
    if (_phase == _Phase.processing || _phase == _Phase.success) return;
    final action = widget.onSwiped;
    if (action == null) return;

    setState(() => _phase = _Phase.processing);
    unawaited(_collapse.forward());

    final ok = await action();
    if (!mounted) return;

    if (ok) {
      setState(() => _phase = _Phase.success);
      await Future<void>.delayed(AppDurations.successDwell);
      if (!mounted) return;
      widget.onSuccess?.call();
      // onSuccess very likely navigated away and disposed this widget; if it
      // didn't, the control should not be left stuck mid-animation.
      if (!mounted) return;
      await _reset();
    } else {
      await _reset();
    }
  }

  Future<void> _reset() async {
    await Future.wait([
      _collapse.reverse(),
      _knob.animateTo(0, curve: Curves.easeOut),
    ]);
    if (mounted) setState(() => _phase = _Phase.idle);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final idle = _phase == _Phase.idle;
    final enabled = widget.onSwiped != null && idle;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // Only sweep while the control is idle and actually actionable.
    _syncShimmer(wanted: enabled && !reduceMotion);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      // Assistive tech activates the action directly — a drag gesture is not
      // something a screen-reader user can perform.
      onTap: enabled ? () => unawaited(_commit()) : null,
      // One node, not two: without this the inner Text publishes the same
      // label again and the control is announced twice.
      container: true,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final travel = width.isFinite
              ? math.max(0.0, width - _knobSize - _inset * 2)
              : 0.0;

          // Tied to widget.onSwiped alone, *not* to `enabled`/`idle`. The
          // first drag update sets _phase to dragging, which flips `enabled`
          // false on the very next rebuild — if these callbacks depended on
          // that, GestureDetector would drop the HorizontalDragGestureRecognizer
          // from its gesture map mid-drag and Flutter disposes it, aborting
          // the gesture after a single pixel of movement. That is invisible
          // to `tester.drag()` (which fires a whole synthetic gesture with no
          // rebuild in between) but killed every real on-device swipe after
          // the first frame. Re-entrancy while processing/success is guarded
          // inside the handlers instead.
          final draggable = widget.onSwiped != null;

          return GestureDetector(
            onHorizontalDragUpdate: draggable
                ? (details) => _onDragUpdate(details, travel)
                : null,
            onHorizontalDragEnd: draggable ? _onDragEnd : null,
            child: SizedBox(
              // Full-bleed by construction — see this widget's callers, which
              // sit under loose-width parents.
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: AnimatedBuilder(
                animation: Listenable.merge([_knob, _collapse]),
                builder: (context, _) {
                  if (_phase == _Phase.processing || _phase == _Phase.success) {
                    return _CollapsingKnob(
                      fullWidth: width.isFinite ? width : AppSizes.buttonHeight,
                      progress: _collapse.value,
                      colors: colors,
                      success: _phase == _Phase.success,
                    );
                  }
                  return _Track(
                    colors: colors,
                    enabled: widget.onSwiped != null,
                    label: widget.label,
                    knobValue: _knob.value,
                    travel: travel,
                    shimmer: _shimmerRunning ? _shimmer : null,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The idle/dragging visual: a plum pill with the label and the gold arrow
/// knob.
class _Track extends StatelessWidget {
  const _Track({
    required this.colors,
    required this.enabled,
    required this.label,
    required this.knobValue,
    required this.travel,
    required this.shimmer,
  });

  final WishtickColors colors;
  final bool enabled;
  final String label;
  final double knobValue;
  final double travel;
  final Animation<double>? shimmer;

  static const _knobSize = 32.0;
  static const _inset = (AppSizes.buttonHeight - _knobSize) / 2;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? colors.primary : colors.border,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Label(
            text: label,
            colors: colors,
            enabled: enabled,
            // Fades out as the knob travels, so the label never sits under
            // the moving disc.
            opacity: (1 - knobValue * 1.6).clamp(0.0, 1.0),
            shimmer: shimmer,
            reserved: _knobSize + _inset * 2,
          ),
          Positioned(
            left: _inset + travel * knobValue,
            child: Container(
              width: _knobSize,
              height: _knobSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? colors.celebration : colors.surfaceAlt,
              ),
              child: Icon(
                Icons.chevron_right,
                size: AppSizes.iconMd,
                color: enabled ? colors.onPrimary : colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The processing/success visual: the track collapses in from both edges into
/// a circle centred on the button, so a spinner reads as its own loading
/// indicator rather than a leftover fragment of the track. A spinner runs
/// while [success] is false; once true it swaps for a check with no further
/// layout change.
class _CollapsingKnob extends StatelessWidget {
  const _CollapsingKnob({
    required this.fullWidth,
    required this.progress,
    required this.colors,
    required this.success,
  });

  static const _knobSize = 32.0;

  final double fullWidth;
  final double progress;
  final WishtickColors colors;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final width = lerpDouble(fullWidth, _knobSize, progress)!;
    final height = lerpDouble(AppSizes.buttonHeight, _knobSize, progress)!;

    return Align(
      alignment: Alignment.center,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Center(
          child: success
              ? Icon(
                  Icons.check,
                  size: AppSizes.iconMd,
                  color: colors.onPrimary,
                )
              : SizedBox(
                  width: AppSizes.iconMd,
                  height: AppSizes.iconMd,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(colors.onPrimary),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.text,
    required this.colors,
    required this.enabled,
    required this.opacity,
    required this.shimmer,
    required this.reserved,
  });

  final String text;
  final WishtickColors colors;
  final bool enabled;
  final double opacity;

  /// Null when the sheen is off (disabled control, or reduced motion).
  final Animation<double>? shimmer;

  /// Horizontal room kept clear on *both* sides for the knob, so the label
  /// stays optically centred on the track rather than shifted by the disc.
  final double reserved;

  @override
  Widget build(BuildContext context) {
    final base = enabled ? colors.onPrimary : colors.textMuted;

    Widget label = Text(
      text,
      maxLines: 1,
      style: context.text.labelLarge?.copyWith(color: base),
    );

    final sweep = shimmer;
    if (sweep != null) {
      label = AnimatedBuilder(
        animation: sweep,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            // One colour at two alphas: a sheen travelling across the text,
            // rather than a second colour appearing in it.
            colors: [
              base.withValues(alpha: 0.45),
              base,
              base.withValues(alpha: 0.45),
            ],
            transform: _SlidingGradient(sweep.value * 2 - 1),
          ).createShader(bounds),
          child: child,
        ),
        child: label,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: reserved),
      child: Opacity(
        opacity: opacity,
        // The footer's track is much narrower than the full-width one, so the
        // label scales down rather than overflowing.
        child: FittedBox(fit: BoxFit.scaleDown, child: label),
      ),
    );
  }
}

/// Slides a gradient horizontally by a fraction of the shader bounds.
class _SlidingGradient extends GradientTransform {
  const _SlidingGradient(this.slide);

  final double slide;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slide, 0, 0);
}
