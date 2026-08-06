import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// Formats a hold as `HH : MM : SS`, counting hours rather than rolling into
/// days — a 72-hour hold reads as `72 : 00 : 00`, which is what the reservation
/// card is telling you.
String formatHoldCountdown(Duration left) {
  final hours = left.inHours;
  final minutes = left.inMinutes.remainder(60);
  final seconds = left.inSeconds.remainder(60);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(hours)} : ${two(minutes)} : ${two(seconds)}';
}

/// Figma `299:1371` — the confirmation before an item is claimed.
///
/// The mock prints `48 : 00 : 00`. This renders the window the server actually
/// applies instead of that constant: the hold's length is an environment
/// setting, and a sheet promising 48 hours over a 72-hour hold would be wrong
/// the moment either changed.
class ReserveGiftSheet extends StatefulWidget {
  const ReserveGiftSheet({required this.holdDuration, super.key});

  final Duration holdDuration;

  /// Resolves true when the gift should be reserved.
  static Future<bool> show(
    BuildContext context, {
    required Duration holdDuration,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReserveGiftSheet(holdDuration: holdDuration),
    );
    return result ?? false;
  }

  @override
  State<ReserveGiftSheet> createState() => _ReserveGiftSheetState();
}

class _ReserveGiftSheetState extends State<ReserveGiftSheet> {
  late Duration _left = widget.holdDuration;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Ticks so the number is alive rather than a printed constant. Nothing is
    // reserved yet, so this is the length of the window on offer, counting
    // down from the moment the sheet opened.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _left = _left - const Duration(seconds: 1);
        if (_left.isNegative) _left = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The mock's close affordance floats above the sheet's rounded top.
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Material(
            color: colors.surface,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(false),
              icon: Icon(Icons.close, color: colors.textPrimary),
              tooltip: 'Close',
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxxl,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Reserve this Gift?',
                  style: context.text.headlineSmall?.copyWith(
                    // Same reason as the celebration screens: plum measures
                    // 1.61:1 on the dark page.
                    color: context.headlineBrandColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'This item will be reserved by you so others cannot '
                  'purchase it.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _CountdownCard(left: _left),
                const SizedBox(height: AppSpacing.xxl),
                const _NoteRow(
                  icon: Icons.schedule,
                  text:
                      'You can complete the purchase anytime before the '
                      'expiry.',
                ),
                const SizedBox(height: AppSpacing.lg),
                const _NoteRow(
                  icon: Icons.event_available_outlined,
                  text:
                      'If not purchased, reservation will be automatically '
                      'released.',
                ),
                const SizedBox(height: AppSpacing.xxxl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Yes, Reserve it'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.left});

  final Duration left;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxxl,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Text(
            'Reservation expires in',
            style: context.text.titleMedium?.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatHoldCountdown(left),
            style: context.text.headlineMedium?.copyWith(
              // Gold, as in the mock — the clock is a countdown, not an alert,
              // and the magenta accent reads as one.
              color: colors.celebration,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Hours : Minutes : Seconds',
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppSizes.avatarSm,
          height: AppSizes.avatarSm,
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: AppSizes.iconSm, color: colors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: context.text.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
