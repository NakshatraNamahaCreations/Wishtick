import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../domain/memory.dart';
import 'add_wish_controller.dart';
import 'memory_providers.dart';
import 'widgets/memory_players.dart';

/// "Preview" before a wish is sealed in — `2074:76` (photo), `2240:71` (text),
/// `2078:202` (audio), `2078:255` (video).
///
/// One screen for all four: the frames differ only in the card at the top, and
/// every one of them closes with the same `To <person>` line and Continue.
/// The combined preview (`2219:554`) is not exported; the card here is built
/// from the photo and text frames, which is what it would have composed.
class MemoryWishPreviewScreen extends ConsumerWidget {
  const MemoryWishPreviewScreen({required this.memoryId, super.key});

  final String memoryId;

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final wish = await ref.read(addWishProvider(memoryId).notifier).submit();
    if (wish == null || !context.mounted) return;
    // The capsule's counts and contributor names both change.
    ref.invalidate(memoryProvider(memoryId));
    ref.invalidate(myMemoriesProvider);
    ref.invalidate(contributedMemoriesProvider);
    context.go(AppRoutes.memory(memoryId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(addWishProvider(memoryId));
    final capsule = ref.watch(memoryProvider(memoryId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(
        context,
        title: state.kind == MemoryWishKind.audio ? 'Audio Preview' : 'Preview',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _WishCard(state: state),
          const SizedBox(height: AppSpacing.section),
          // "To <person> / <relation>" — the reassurance that it is going to
          // the right capsule.
          capsule.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (memory) => Row(
              children: [
                CircleAvatar(
                  radius: AppSizes.avatarMd / 2,
                  backgroundColor: colors.optionFill,
                  child: Text(
                    memory.personName.characters.first.toUpperCase(),
                    style: context.text.titleMedium?.copyWith(
                      color: colors.primaryMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To',
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      memory.personName,
                      style: context.text.titleSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      memory.title,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            WishtickErrorText(state.error!),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.busy ? null : () => _send(context, ref),
              child: state.busy
                  ? SizedBox(
                      width: AppSizes.iconMd,
                      height: AppSizes.iconMd,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Text('Continue'),
            ),
          ),
        ),
      ),
    );
  }
}

/// The wish as it will appear in the story.
class _WishCard extends StatelessWidget {
  const _WishCard({required this.state});

  final AddWishState state;

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
          switch (state.kind) {
            MemoryWishKind.photo => AspectRatio(
              aspectRatio: 1,
              child: WishtickImage(
                url: state.mediaUrl,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            MemoryWishKind.audio => _AudioRow(url: state.mediaUrl),
            MemoryWishKind.video => _VideoRow(url: state.mediaUrl),
            MemoryWishKind.text => const SizedBox.shrink(),
          },
          if (state.kind == MemoryWishKind.text) ...[
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
              state.text,
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(
                color: context.headlineBrandColor,
                height: 1.5,
              ),
            ),
          ] else if (state.text.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              state.text,
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
