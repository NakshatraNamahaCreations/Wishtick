import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../domain/memory.dart';

/// The countdown chip a sealed capsule card wears ("Unlocks in 5 days").
class MemoryCountdownChip extends StatelessWidget {
  const MemoryCountdownChip({required this.capsule, super.key});

  final MemoryCapsule capsule;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            capsule.isOpen ? Icons.lock_open : Icons.calendar_today_outlined,
            size: AppSizes.iconSm,
            color: colors.textPrimary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            capsule.countdownLabel,
            style: context.text.bodySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The wide capsule card the three carousels on `4104:1433` are made of.
///
/// Its own cover photographs behind a scrim rather than a flat fill: the frame
/// shows the artwork bleeding to the card's edge with the text over it, and a
/// capsule with no cover still needs to be readable — hence the fallback tint.
class MemoryCard extends StatelessWidget {
  const MemoryCard({
    required this.capsule,
    required this.onTap,
    this.width = 344,
    super.key,
  });

  final MemoryCapsule capsule;
  final VoidCallback onTap;
  final double width;

  static const height = 232.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: colors.primaryDeep,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (capsule.coverUrl != null)
                WishtickImage(url: capsule.coverUrl, fit: BoxFit.cover),
              // The scrim is what keeps the title legible over any photo.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primaryDeep.withValues(alpha: 0.92),
                      colors.primaryDeep.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MemoryCountdownChip(capsule: capsule),
                    const Spacer(),
                    Text(
                      capsule.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleLarge?.copyWith(
                        color: colors.textOnDark,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if (capsule.description != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        capsule.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium?.copyWith(
                          color: colors.textOnDark.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: AppSizes.iconSm,
                          color: colors.textOnDark,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            DateFormat(
                              'd MMM yyyy, h:mm a',
                            ).format(capsule.unlockAt.toLocal()),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                              color: colors.textOnDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// One circle in the "Unlocked Memories" row.
class UnlockedMemoryAvatar extends StatelessWidget {
  const UnlockedMemoryAvatar({
    required this.capsule,
    required this.onTap,
    super.key,
  });

  final MemoryCapsule capsule;
  final VoidCallback onTap;

  static const _size = 86.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: _size + AppSpacing.lg,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: _size,
              height: _size,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // The ring is what says "there is something to open in here".
                border: Border.all(color: colors.accent, width: 2),
              ),
              child: ClipOval(
                child: capsule.coverUrl != null
                    ? WishtickImage(url: capsule.coverUrl, fit: BoxFit.cover)
                    : ColoredBox(
                        color: colors.optionFill,
                        child: Center(
                          child: Text(
                            capsule.personName.characters.first.toUpperCase(),
                            style: context.text.titleLarge?.copyWith(
                              color: colors.primaryMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            capsule.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
