import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/media/media_playback.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// `mm:ss`, the way both transport rows read a time.
String formatClock(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// The little bar chart behind a voice note.
///
/// A fixed pattern, not the file's real amplitudes: decoding the audio to draw
/// forty bars would cost more than the bars are worth, and the design uses it
/// as an ornament. [progress] fills it left-to-right as the note plays, which
/// is the part that has to be true.
class MemoryWaveform extends StatelessWidget {
  const MemoryWaveform({
    this.height = 28,
    this.bars = 28,
    this.progress = 0,
    this.color,
    this.playedColor,
    super.key,
  });

  final double height;
  final int bars;

  /// 0–1. Bars to its left are drawn in [playedColor].
  final double progress;

  final Color? color;
  final Color? playedColor;

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
    final base = color ?? context.colors.primary;
    final played = playedColor ?? base;
    final upTo = (bars * progress.clamp(0, 1)).round();

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
                  color: i < upTo ? played : base.withValues(alpha: 0.35),
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

/// A voice note, playable — the card of `2078:529`.
///
/// Owns its own [AudioPlayer] and disposes it: a player left running behind a
/// popped route keeps talking over whatever comes next.
class MemoryAudioPlayer extends StatefulWidget {
  const MemoryAudioPlayer({
    required this.url,
    this.ink,
    this.inkMuted,
    this.autoPlay = false,
    this.onCompleted,
    super.key,
  });

  final String url;
  final Color? ink;
  final Color? inkMuted;
  final bool autoPlay;

  /// Fired once when the note reaches its end — the story advances on it.
  final VoidCallback? onCompleted;

  @override
  State<MemoryAudioPlayer> createState() => _MemoryAudioPlayerState();
}

class _MemoryAudioPlayerState extends State<MemoryAudioPlayer> {
  final _player = AudioPlayer();
  bool _failed = false;
  bool _announcedCompletion = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // A file the host has picked but not uploaded yet is a path, not a URL.
      if (isRemoteMedia(widget.url)) {
        await _player.setUrl(widget.url);
      } else {
        await _player.setFilePath(widget.url);
      }
      if (!mounted) return;
      if (widget.autoPlay) await _player.play();
    } catch (e) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _seekBy(Duration by) async {
    final target = _player.position + by;
    final total = _player.duration ?? Duration.zero;
    await _player.seek(
      target < Duration.zero
          ? Duration.zero
          : (target > total ? total : target),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = widget.ink ?? context.colors.textPrimary;
    final muted = widget.inkMuted ?? context.colors.textSecondary;

    if (_failed) {
      return Center(
        child: Text(
          'This voice note could not be played.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: muted),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        final total = _player.duration ?? Duration.zero;
        final progress = total.inMilliseconds == 0
            ? 0.0
            : position.inMilliseconds / total.inMilliseconds;

        return StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          builder: (context, stateSnapshot) {
            final playing = stateSnapshot.data?.playing ?? false;
            final done =
                stateSnapshot.data?.processingState ==
                ProcessingState.completed;
            // Fired from the build rather than a listener so it cannot outlive
            // the widget; the flag keeps it to once per note.
            if (done && !_announcedCompletion) {
              _announcedCompletion = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => widget.onCompleted?.call(),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MemoryWaveform(
                  height: 56,
                  bars: 24,
                  progress: progress,
                  color: ink,
                  playedColor: ink,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  children: [
                    Text(
                      formatClock(position),
                      style: context.text.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0, 1),
                          minHeight: 3,
                          backgroundColor: ink.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation(ink),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      formatClock(total),
                      style: context.text.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TransportButton(
                      icon: Icons.replay_5,
                      color: ink,
                      onTap: () => _seekBy(const Duration(seconds: -5)),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    _PlayPauseButton(
                      playing: playing,
                      onTap: () async {
                        if (playing) {
                          await _player.pause();
                        } else {
                          // Replaying after the end starts from the top.
                          if (done) {
                            await _player.seek(Duration.zero);
                            _announcedCompletion = false;
                          }
                          await _player.play();
                        }
                      },
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    _TransportButton(
                      icon: Icons.forward_5,
                      color: ink,
                      onTap: () => _seekBy(const Duration(seconds: 5)),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    icon: Icon(icon),
    iconSize: AppSizes.iconLg + AppSpacing.xs,
    color: color,
  );
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      // The one light disc in the transport row, as the frame draws it.
      color: colors.surfaceAlt,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            size: AppSizes.iconLg,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// A video wish, playable — `2078:390` in the story, `2078:255` in the preview.
///
/// Holds on its first frame with a play button until tapped, which is what the
/// preview frame shows; [autoPlay] starts it immediately for the story.
class MemoryVideoPlayer extends StatefulWidget {
  const MemoryVideoPlayer({
    required this.url,
    this.autoPlay = false,
    this.showProgress = true,
    this.ink,
    this.onCompleted,
    super.key,
  });

  final String url;
  final bool autoPlay;
  final bool showProgress;
  final Color? ink;
  final VoidCallback? onCompleted;

  @override
  State<MemoryVideoPlayer> createState() => _MemoryVideoPlayerState();
}

class _MemoryVideoPlayerState extends State<MemoryVideoPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  /// The clip exists but is still being transcoded — a temporary state that
  /// must not be shown as a failure.
  bool _processing = false;

  bool _announcedCompletion = false;
  Timer? _retry;

  /// Backs off rather than hammering: an encode takes tens of seconds, and a
  /// tight poll would spend a phone's battery to learn nothing sooner.
  static const _retryDelays = <Duration>[
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 8),
    Duration(seconds: 13),
    Duration(seconds: 20),
  ];
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final remote = isRemoteMedia(widget.url);

    if (remote) {
      // Ask before opening the player: a still-encoding clip answers 409, and a
      // VideoPlayerController handed that just fails, which reads on screen as
      // a broken video rather than one that is nearly ready. A local file has
      // nothing to ask — there is no server in it.
      final readiness = await probePlayback(widget.url);
      if (!mounted) return;

      if (readiness == PlaybackReadiness.processing) {
        setState(() => _processing = true);
        _scheduleRetry();
        return;
      }
      if (readiness == PlaybackReadiness.unavailable) {
        setState(() => _failed = true);
        return;
      }
    }

    final controller = remote
        ? VideoPlayerController.networkUrl(Uri.parse(widget.url))
        : VideoPlayerController.file(File(widget.url));
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onTick);
      setState(() {
        _controller = controller;
        _processing = false;
      });
      if (widget.autoPlay) await controller.play();
    } catch (e) {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  void _scheduleRetry() {
    if (_attempt >= _retryDelays.length) {
      // Still encoding after ~50 seconds of waiting. Stop the timer and leave
      // the message up — it is accurate, and the screen can be reopened.
      return;
    }
    _retry = Timer(_retryDelays[_attempt++], () {
      if (mounted) unawaited(_load());
    });
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final value = controller.value;
    if (value.position >= value.duration &&
        value.duration > Duration.zero &&
        !_announcedCompletion) {
      _announcedCompletion = true;
      widget.onCompleted?.call();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _retry?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = widget.ink ?? context.colors.textOnDark;

    if (_processing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: AppSizes.iconLg,
              height: AppSizes.iconLg,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(ink),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Getting this video ready…',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: ink),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'It will play here in a moment.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(
                color: ink.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      );
    }

    if (_failed) {
      return Center(
        child: Text(
          'This video could not be played.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: ink),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final value = controller.value;
    return GestureDetector(
      // Its own tap, so the story's advance-on-tap does not skip the video the
      // moment someone reaches for play.
      onTap: () async {
        if (value.isPlaying) {
          await controller.pause();
        } else {
          if (value.position >= value.duration) {
            await controller.seekTo(Duration.zero);
            _announcedCompletion = false;
          }
          await controller.play();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          if (!value.isPlaying)
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: context.colors.overlay,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Icon(
                  Icons.play_arrow,
                  size: AppSizes.avatarMd,
                  color: ink,
                ),
              ),
            ),
          if (widget.showProgress)
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Row(
                children: [
                  Text(
                    formatClock(value.position),
                    style: context.text.bodySmall?.copyWith(color: ink),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      child: LinearProgressIndicator(
                        value: value.duration.inMilliseconds == 0
                            ? 0
                            : value.position.inMilliseconds /
                                  value.duration.inMilliseconds,
                        minHeight: 3,
                        backgroundColor: ink.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation(ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    formatClock(value.duration),
                    style: context.text.bodySmall?.copyWith(color: ink),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
