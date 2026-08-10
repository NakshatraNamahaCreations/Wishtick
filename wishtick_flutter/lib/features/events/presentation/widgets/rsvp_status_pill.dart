import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../domain/event.dart';

/// The Confirmed / May be / Declined pill on the guest list (`4099:1256`).
class RsvpStatusPill extends StatelessWidget {
  const RsvpStatusPill({required this.rsvp, super.key});

  final RsvpResponse rsvp;

  /// Fixed so the pills line up down the right edge as the design shows —
  /// "Confirmed" and "May be" are very different widths.
  static const width = 108.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (fill, ink) = switch (rsvp) {
      RsvpResponse.yes => (colors.successSubtle, colors.onSuccessSubtle),
      RsvpResponse.maybe => (colors.warningSubtle, colors.onWarningSubtle),
      RsvpResponse.no => (colors.dangerSubtle, colors.onDangerSubtle),
      RsvpResponse.pending => (colors.chipFill, colors.textSecondary),
    };

    return Container(
      width: width,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        rsvp.label,
        style: context.text.bodyMedium?.copyWith(color: ink),
      ),
    );
  }
}
