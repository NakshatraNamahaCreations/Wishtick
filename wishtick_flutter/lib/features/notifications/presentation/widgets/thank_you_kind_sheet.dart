import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../domain/thank_you_note.dart';

/// "How would you like to thank them?" (`2012:109`).
///
/// A bottom sheet with a close button floating above it, exactly as the frame
/// draws it. Returns the chosen kind, or null if dismissed.
Future<ThankYouKind?> showThankYouKindSheet(BuildContext context) {
  return showModalBottomSheet<ThankYouKind>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: context.colors.overlay,
    isScrollControlled: true,
    builder: (sheetContext) => const _ThankYouKindSheet(),
  );
}

class _ThankYouKindSheet extends StatelessWidget {
  const _ThankYouKindSheet();

  static const _options = <(ThankYouKind, IconData, String, String)>[
    (
      ThankYouKind.text,
      Icons.mark_email_read_outlined,
      'Text Message',
      'Write a heartfelt message',
    ),
    (
      ThankYouKind.photo,
      Icons.image_outlined,
      'Photo Message',
      'Share a photo',
    ),
    (
      ThankYouKind.audio,
      Icons.mic_none,
      'Voice Note',
      'Record a voice message',
    ),
    (
      ThankYouKind.video,
      Icons.videocam_outlined,
      'Video Message',
      'Record a video',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The close button sits *above* the sheet in the frame, not inside it.
        Material(
          color: colors.surface,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: AppSizes.minTapTarget,
              height: AppSizes.minTapTarget,
              child: Icon(Icons.close, color: colors.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.xxxl,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How would you like to\nthank them?',
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineSmall.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  for (var i = 0; i < _options.length; i += 2) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _Option(option: _options[i])),
                        Expanded(
                          child: i + 1 < _options.length
                              ? _Option(option: _options[i + 1])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    if (i + 2 < _options.length)
                      const SizedBox(height: AppSpacing.xxxl),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.option});

  final (ThankYouKind, IconData, String, String) option;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (kind, icon, title, subtitle) = option;

    return InkWell(
      onTap: () => Navigator.of(context).pop(kind),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: colors.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
