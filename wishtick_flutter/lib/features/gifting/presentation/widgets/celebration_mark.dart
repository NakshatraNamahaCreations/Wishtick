import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// The confetti burst behind the order-confirmed and gift-delivered marks
/// (Figma `299:1486`, `299:1620`).
///
/// The mocks use bespoke illustrations — a magenta heart-with-tick and a purple
/// gift box, both surrounded by drawn confetti. Neither is in `UI_Screen/`, so
/// this composes the same shape out of what the app already has: the confetti
/// package (as on "You're all set!") around whatever mark the caller supplies.
/// Swapping in the real artwork is then a one-argument change.
class CelebrationMark extends StatefulWidget {
  const CelebrationMark({required this.child, this.size = 120, super.key});

  /// The confetti's centrepiece, already sized by the caller.
  final Widget child;

  /// Half the burst's width. The confetti fills a box twice this across.
  final double size;

  @override
  State<CelebrationMark> createState() => _CelebrationMarkState();
}

class _CelebrationMarkState extends State<CelebrationMark> {
  late final ConfettiController _confetti = ConfettiController(
    duration: AppDurations.confettiBurst,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Skipped under reduced motion for the same two reasons as the onboarding
    // burst: it is a real accessibility setting, and the package keeps
    // scheduling frames forever, which would stop a widget test settling.
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
    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 24,
            maxBlastForce: 16,
            minBlastForce: 6,
            gravity: 0.15,
            colors: [
              colors.celebration,
              colors.info,
              colors.accent,
              colors.primaryMuted,
              colors.primary,
            ],
          ),
          widget.child,
        ],
      ),
    );
  }
}
