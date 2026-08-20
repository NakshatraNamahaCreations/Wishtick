import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/theme_extensions.dart';

/// A success message that fades and slides in, holds for [dwell], then fades
/// and slides back out and calls [onDismissed].
///
/// Stateless about "shown" — the caller mounts/unmounts this widget and
/// supplies a fresh [Key] each time, which is what replays the animation for
/// a second, immediately-following success rather than being a no-op because
/// the widget is still in its dwell.
class SuccessBanner extends StatefulWidget {
  const SuccessBanner({
    super.key,
    required this.message,
    this.dwell = AppDurations.toastDwell,
    this.onDismissed,
  });

  final String message;
  final Duration dwell;
  final VoidCallback? onDismissed;

  @override
  State<SuccessBanner> createState() => _SuccessBannerState();
}

class _SuccessBannerState extends State<SuccessBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.normal,
  );
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _dismissTimer = Timer(widget.dwell, _startExit);
  }

  Future<void> _startExit() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed?.call();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.25),
          end: Offset.zero,
        ).animate(curve),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: colors.successSubtle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                size: AppSizes.iconMd,
                color: colors.onSuccessSubtle,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.message,
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.onSuccessSubtle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
