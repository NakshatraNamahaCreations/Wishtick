import 'package:flutter/material.dart';

import '../../../../core/media/media_limits.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../domain/memory.dart';
import 'memory_players.dart';

/// What the file picker offers for a wish of this kind.
///
/// One list, read by both the picker and the hint printed above it. Kept
/// together deliberately: when they were written out separately in each compose
/// screen, nothing stopped the screen offering `.mov` while the caption
/// promised only MP4.
List<String> wishMediaExtensions(MemoryWishKind kind) => switch (kind) {
  MemoryWishKind.photo => const ['jpg', 'jpeg', 'png', 'webp', 'heic'],
  MemoryWishKind.video => const ['mp4', 'mov'],
  MemoryWishKind.audio => const ['mp3', 'm4a', 'aac', 'wav'],
  MemoryWishKind.text => const [],
};

/// "MP4 or MOV · up to 20s · 10 MB" — what will be accepted, before anything is
/// picked.
///
/// `jpeg` is folded into `jpg` and `m4a` into `mp3`'s line only where the pair
/// would read as two names for one thing; everything else is listed as the
/// picker will actually filter, so the caption cannot promise a format the
/// picker then refuses to show.
///
/// The duration comes first when there is one: it is the limit a person can do
/// something about while filming, and the one they are far likelier to hit.
String wishMediaHint(MemoryWishKind kind, PurposeLimit limit) {
  final formats = switch (kind) {
    MemoryWishKind.photo => 'JPG, PNG, WEBP or HEIC',
    MemoryWishKind.video => 'MP4 or MOV',
    MemoryWishKind.audio => 'MP3, M4A, AAC or WAV',
    MemoryWishKind.text => '',
  };
  // Only where a duration is a thing this kind has. A photo has no length, and
  // "up to 20s" over a still-image picker is nonsense.
  final duration = kind == MemoryWishKind.photo ? null : limit.durationLabel;
  return [
    formats,
    if (duration != null) 'up to $duration',
    duration == null ? 'up to ${limit.label}' : limit.label,
  ].join(' · ');
}

/// The picked photo, video or voice note on a compose screen, with the ✕ that
/// takes it back off.
///
/// Shared by the two places a wish is composed — a contributor adding one to
/// somebody else's capsule, and a host recording the first wish while creating
/// their own. Both draw exactly this block, so it lives here rather than
/// twice.
class WishMediaBlock extends StatelessWidget {
  const WishMediaBlock({
    super.key,
    required this.kind,
    required this.mediaUrl,
    required this.fileName,
    required this.uploading,
    required this.onPick,
    required this.onClear,
    this.sizeLimit,
  });

  final MemoryWishKind kind;
  final String? mediaUrl;
  final String? fileName;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onClear;

  /// The cap, said out loud before anything is picked — "MP4 or MOV · up to
  /// 10 MB". A limit only ever mentioned in the error that enforces it makes
  /// the user find it by failing, after they have already chosen a clip and
  /// walked two screens further on.
  final String? sizeLimit;

  static const _height = 300.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (uploading) {
      return SizedBox(
        height: _height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Uploading…',
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (mediaUrl == null) {
      return SizedBox(
        height: _height,
        child: Material(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    switch (kind) {
                      MemoryWishKind.photo =>
                        Icons.add_photo_alternate_outlined,
                      MemoryWishKind.video => Icons.video_call_outlined,
                      MemoryWishKind.audio => Icons.mic_none,
                      MemoryWishKind.text => Icons.edit_outlined,
                    },
                    size: AppSizes.avatarMd,
                    color: colors.primaryMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    switch (kind) {
                      MemoryWishKind.photo => 'Add a photo',
                      MemoryWishKind.video => 'Add a video',
                      MemoryWishKind.audio => 'Add a voice note',
                      MemoryWishKind.text => 'Write something',
                    },
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  if (sizeLimit != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      sizeLimit!,
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: _height,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: switch (kind) {
                MemoryWishKind.photo => WishtickImage(url: mediaUrl),
                // Playable right here, so nobody sends a video they have not
                // watched back.
                MemoryWishKind.video => ColoredBox(
                  color: colors.primaryDeep,
                  child: MemoryVideoPlayer(url: mediaUrl!),
                ),
                MemoryWishKind.audio => ColoredBox(
                  color: colors.primaryDeep,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          fileName ?? 'Voice Note',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(
                            color: colors.textOnDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        MemoryAudioPlayer(
                          url: mediaUrl!,
                          ink: colors.textOnDark,
                          inkMuted: colors.textOnDark,
                        ),
                      ],
                    ),
                  ),
                ),
                MemoryWishKind.text => const SizedBox.shrink(),
              },
            ),
          ),
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: Material(
              color: colors.overlay,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Icon(
                    Icons.close,
                    size: AppSizes.iconMd,
                    color: colors.textOnDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
