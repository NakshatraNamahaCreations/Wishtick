import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../domain/memory.dart';
import 'memory_players.dart';

/// What a wish will look like once it is in the capsule.
///
/// Takes the three things it draws rather than a controller's state, so the
/// same card serves a contributor previewing a wish for someone else's memory
/// and a host previewing the first wish of their own — two different drafts,
/// one appearance.
class WishPreviewCard extends StatelessWidget {
  const WishPreviewCard({
    required this.kind,
    required this.mediaUrl,
    required this.text,
    super.key,
  });

  final MemoryWishKind kind;
  final String? mediaUrl;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        // Stretch, not start: a text wish is centred in the frame, and a
        // centred Text that only spans its own content centres nothing.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switch (kind) {
            MemoryWishKind.photo => AspectRatio(
              aspectRatio: 1,
              child: WishtickImage(
                url: mediaUrl,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            MemoryWishKind.audio => _AudioRow(url: mediaUrl),
            MemoryWishKind.video => _VideoRow(url: mediaUrl),
            MemoryWishKind.text => const SizedBox.shrink(),
          },
          if (kind == MemoryWishKind.text) ...[
            Center(
              child: Text(
                'Text Note',
                style: context.text.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              text,
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(
                color: context.headlineBrandColor,
                height: 1.5,
              ),
            ),
          ] else if (text.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              text,
              style: context.text.bodyLarge?.copyWith(
                color: colors.textPrimary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The headphones tile of `2078:202`, with the note playable beside it.
class _AudioRow extends StatelessWidget {
  const _AudioRow({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: colors.primaryDeep,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            Icons.headphones,
            size: AppSizes.avatarMd,
            color: colors.textOnDark,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice Note',
                style: context.text.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (url != null)
                MemoryAudioPlayer(url: url!)
              else
                const MemoryWaveform(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The video, holding on its first frame under a play button (`2078:255`).
class _VideoRow extends StatelessWidget {
  const _VideoRow({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ColoredBox(
          color: colors.primaryDeep,
          child: url == null
              ? Icon(
                  Icons.play_circle_outline,
                  size: AppSizes.avatarLg / 2,
                  color: colors.textOnDark,
                )
              : MemoryVideoPlayer(url: url!),
        ),
      ),
    );
  }
}

/// The little bar chart that stands in for a voice note's waveform.
///
/// Drawn from a fixed pattern rather than the file's real amplitudes: decoding
/// audio on the client to draw forty bars would cost more than the bars are
/// worth, and the design uses it as an ornament, not a readout.
class MemoryWaveform extends StatelessWidget {
  const MemoryWaveform({this.height = 28, this.bars = 28, super.key});

  final double height;
  final int bars;

  static const _pattern = <double>[
    0.3,
    0.6,
    0.9,
    0.5,
    0.75,
    1,
    0.45,
    0.65,
    0.35,
    0.85,
    0.55,
    0.95,
    0.4,
    0.7,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < bars; i++) ...[
            Expanded(
              child: Container(
                height: height * _pattern[i % _pattern.length],
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ),
            if (i != bars - 1) const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}
