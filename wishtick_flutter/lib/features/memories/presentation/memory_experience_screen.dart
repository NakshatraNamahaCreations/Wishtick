import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/share/share_messages.dart' as messages;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/memories_repository.dart';
import '../domain/memory.dart';
import 'memory_providers.dart';
import 'widgets/memory_players.dart';

/// The full experience (`2078:357`, variants `2078:390`, `2078:529`,
/// `2078:592`) — one wish per story segment.
///
/// Always drawn on the dark ground the frames use, in both app themes: this is
/// a lights-down moment, and a beige page would not be the same screen.
class MemoryExperienceScreen extends ConsumerStatefulWidget {
  const MemoryExperienceScreen({required this.memoryId, super.key});

  final String memoryId;

  @override
  ConsumerState<MemoryExperienceScreen> createState() =>
      _MemoryExperienceScreenState();
}

class _MemoryExperienceScreenState
    extends ConsumerState<MemoryExperienceScreen> {
  int _index = 0;

  /// How long a still segment holds before advancing. A media segment runs to
  /// the end of its clip instead and advances on that — a timer would cut a
  /// voice note off mid-sentence.
  static const _stillDwell = Duration(seconds: 6);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTimer(MemoryWish wish) {
    _timer?.cancel();
    if (wish.kind == MemoryWishKind.audio ||
        wish.kind == MemoryWishKind.video) {
      return;
    }
    _timer = Timer(_stillDwell, () {
      if (mounted) _advance(1);
    });
  }

  void _advance(int by) {
    final wishes = ref.read(memoryProvider(widget.memoryId)).value?.wishes;
    if (wishes == null || wishes.isEmpty) return;
    final next = _index + by;
    if (next < 0) return;
    if (next >= wishes.length) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _index = next);
    _restartTimer(wishes[next]);
  }

  Future<void> _react(MemoryWish wish) async {
    try {
      await ref
          .read(memoriesRepositoryProvider)
          .react(widget.memoryId, wish.id);
      ref.invalidate(memoryProvider(widget.memoryId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send that reaction.')),
      );
    }
  }

  Future<void> _share(MemoryCapsule capsule) async {
    await SharePlus.instance.share(
      ShareParams(
        // Carries its link now: this used to be a sentence about something
        // the reader had no way to go and look at.
        text: messages
            .memoryOpened(
              title: capsule.title,
              wishCount: capsule.wishCount,
              slug: capsule.share?.slug ?? '',
              senderName: ref.read(sessionProvider).user?.name,
            )
            .combined,
        subject: capsule.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capsule = ref.watch(memoryProvider(widget.memoryId));

    return Scaffold(
      backgroundColor: _MemoryStoryPalette.background,
      body: SafeArea(
        child: capsule.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(
            child: WishtickErrorText('Could not open this memory.'),
          ),
          data: (memory) {
            if (!memory.isOpen) {
              return _StillSealed(capsule: memory);
            }
            if (memory.wishes.isEmpty) {
              return const _NoWishes();
            }
            final index = _index.clamp(0, memory.wishes.length - 1);
            final wish = memory.wishes[index];

            return Column(
              children: [
                _SegmentBar(count: memory.wishes.length, current: index),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  memory.title,
                  textAlign: TextAlign.center,
                  style: context.text.titleLarge?.copyWith(
                    color: _MemoryStoryPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${memory.wishCount} '
                  '${memory.wishCount == 1 ? 'Wish' : 'Wishes'}',
                  style: context.text.bodyMedium?.copyWith(
                    color: _MemoryStoryPalette.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  // Tap the left third to go back, anywhere else to advance —
                  // the gesture every story viewer has trained people on.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final third = MediaQuery.sizeOf(context).width / 3;
                      _advance(details.localPosition.dx < third ? -1 : 1);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: _WishSegment(
                        // Keyed by wish id so moving between two clips builds a
                        // fresh player rather than re-pointing the old one.
                        key: ValueKey(wish.id),
                        wish: wish,
                        onFinished: () => _advance(1),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StoryAction(
                          icon: Icons.favorite_border,
                          label: 'React',
                          onTap: () => _react(wish),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _StoryAction(
                          icon: Icons.ios_share,
                          label: 'Share',
                          onTap: () => _share(memory),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The story ground, fixed in both themes.
///
/// Reads the **dark** tokens explicitly rather than the active theme's: this is
/// a lights-down moment and the frames are dark, so a viewer in light mode gets
/// the same screen. Tokens rather than literals, so a rebrand still reaches it.
abstract final class _MemoryStoryPalette {
  static Color get background => WishtickColors.dark.background;
  static Color get ink => WishtickColors.dark.textPrimary;
  static Color get inkMuted => WishtickColors.dark.textSecondary;
}

/// The segmented progress bar across the top.
class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: i <= current
                      ? _MemoryStoryPalette.ink
                      : _MemoryStoryPalette.ink.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ),
            if (i != count - 1) const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// One wish, drawn the way its kind's variant frame draws it.
class _WishSegment extends StatelessWidget {
  const _WishSegment({required this.wish, required this.onFinished, super.key});

  final MemoryWish wish;

  /// Fired when a clip reaches its end — the story moves on.
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _MemoryStoryPalette.ink.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(
                color: _MemoryStoryPalette.ink.withValues(alpha: 0.12),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _KindBody(wish: wish, onFinished: onFinished),
                ),
                Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.md,
                  child: _ContributorChip(wish: wish),
                ),
              ],
            ),
          ),
        ),
        // Only under a media wish. A text wish's card *is* its message, and
        // repeating it below reads as the same message sent twice.
        if (wish.kind != MemoryWishKind.text &&
            wish.text != null &&
            wish.text!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            wish.text!,
            style: context.text.bodyLarge?.copyWith(
              color: _MemoryStoryPalette.ink,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _KindBody extends StatelessWidget {
  const _KindBody({required this.wish, required this.onFinished});

  final MemoryWish wish;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) => switch (wish.kind) {
    MemoryWishKind.photo => WishtickImage(url: wish.mediaUrl),
    MemoryWishKind.video =>
      wish.mediaUrl == null
          ? const _MediaPlaceholder(
              icon: Icons.play_circle_outline,
              label: 'Video',
            )
          : MemoryVideoPlayer(
              url: wish.mediaUrl!,
              autoPlay: true,
              ink: _MemoryStoryPalette.ink,
              onCompleted: onFinished,
            ),
    MemoryWishKind.audio => _AudioBody(wish: wish, onFinished: onFinished),
    MemoryWishKind.text => Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Text Note',
            style: context.text.bodySmall?.copyWith(
              color: _MemoryStoryPalette.inkMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            wish.text ?? '',
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(
              color: _MemoryStoryPalette.ink,
              height: 1.6,
            ),
          ),
        ],
      ),
    ),
  };
}

/// The voice-note segment of `2078:529` — waveform, times, transport.
///
/// The transport is presentational: playback needs an audio package the app
/// does not carry yet, so the controls are shown disabled rather than faked
/// into looking like they work.
class _AudioBody extends StatelessWidget {
  const _AudioBody({required this.wish, required this.onFinished});

  final MemoryWish wish;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Voice Note',
            style: context.text.titleMedium?.copyWith(
              color: _MemoryStoryPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (wish.mediaUrl == null)
            const MemoryWaveform(height: 56, bars: 24)
          else
            MemoryAudioPlayer(
              url: wish.mediaUrl!,
              autoPlay: true,
              ink: _MemoryStoryPalette.ink,
              inkMuted: _MemoryStoryPalette.inkMuted,
              onCompleted: onFinished,
            ),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.avatarLg / 2, color: _MemoryStoryPalette.ink),
        const SizedBox(height: AppSpacing.md),
        Text(
          label,
          style: context.text.bodyMedium?.copyWith(
            color: _MemoryStoryPalette.inkMuted,
          ),
        ),
      ],
    ),
  );
}

class _ContributorChip extends StatelessWidget {
  const _ContributorChip({required this.wish});

  final MemoryWish wish;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: AppSizes.avatarSm / 2,
          backgroundColor: _MemoryStoryPalette.ink.withValues(alpha: 0.15),
          child: Text(
            wish.contributorName.characters.first.toUpperCase(),
            style: context.text.bodyMedium?.copyWith(
              color: _MemoryStoryPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          wish.contributorName,
          style: context.text.titleSmall?.copyWith(
            color: _MemoryStoryPalette.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StoryAction extends StatelessWidget {
  const _StoryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _MemoryStoryPalette.ink.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppSizes.iconMd, color: _MemoryStoryPalette.ink),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: context.text.titleSmall?.copyWith(
                  color: _MemoryStoryPalette.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Someone reached the story before the capsule opened. Not an error — the
/// countdown is the answer.
class _StillSealed extends StatelessWidget {
  const _StillSealed({required this.capsule});

  final MemoryCapsule capsule;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: AppSizes.avatarLg / 2,
            color: _MemoryStoryPalette.ink,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            capsule.countdownLabel,
            textAlign: TextAlign.center,
            style: context.text.titleLarge?.copyWith(
              color: _MemoryStoryPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nothing inside can be read until then.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: _MemoryStoryPalette.inkMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _NoWishes extends StatelessWidget {
  const _NoWishes();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Text(
        'This memory opened with nothing inside.',
        textAlign: TextAlign.center,
        style: context.text.bodyLarge?.copyWith(
          color: _MemoryStoryPalette.inkMuted,
        ),
      ),
    ),
  );
}
