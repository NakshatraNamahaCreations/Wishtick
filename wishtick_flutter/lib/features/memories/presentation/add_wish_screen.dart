import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// For XFile, which MediaRepository takes. cross_file is not a direct
// dependency; image_picker re-exports it and is.
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../domain/memory.dart';
import 'add_wish_controller.dart';
import 'memory_wish_preview_screen.dart';
import 'widgets/memory_players.dart';

/// Composing a wish — `2073:55` (photo), `2078:233` (text), `2074:129` (video),
/// and the voice note.
///
/// One screen for all four kinds rather than four: the frames are identical
/// below the media block, down to the "Your Message (Optional)" label and the
/// 40/100 counter. The kind picker at the top is what `2074:152` would have
/// shown; that frame is not exported, so the audio path is **inferred** from
/// the Audio Preview (`2078:202`).
class AddWishScreen extends ConsumerStatefulWidget {
  const AddWishScreen({required this.memoryId, super.key});

  final String memoryId;

  @override
  ConsumerState<AddWishScreen> createState() => _AddWishScreenState();
}

class _AddWishScreenState extends ConsumerState<AddWishScreen> {
  late final _message = TextEditingController(
    text: ref.read(addWishProvider(widget.memoryId)).text,
  );

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  AddWishController get _notifier =>
      ref.read(addWishProvider(widget.memoryId).notifier);

  Future<void> _pickMedia(MemoryWishKind kind) async {
    final extensions = switch (kind) {
      MemoryWishKind.photo => ['jpg', 'jpeg', 'png', 'webp', 'heic'],
      MemoryWishKind.video => ['mp4', 'mov'],
      MemoryWishKind.audio => ['mp3', 'm4a', 'aac', 'wav'],
      MemoryWishKind.text => const <String>[],
    };
    if (extensions.isEmpty) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;

    _notifier.setUploading(true);
    try {
      final media = await ref
          .read(mediaRepositoryProvider)
          .uploadFile(
            file: XFile.fromData(bytes, name: file.name),
            purpose: MediaPurpose.memoryWish,
            // XFile.fromData drops `name` on io, so the real one has to be
            // handed over separately or a .m4a uploads as a JPEG.
            fileName: file.name,
          );
      _notifier.setMedia(
        mediaId: media.id,
        mediaUrl: media.url,
        fileName: file.name,
      );
    } catch (e) {
      _notifier.fail('Could not upload that file. Try again.');
    }
  }

  Future<void> _preview() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MemoryWishPreviewScreen(memoryId: widget.memoryId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(addWishProvider(widget.memoryId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: state.kind.label),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _KindPicker(
            selected: state.kind,
            onSelect: (kind) {
              _notifier.setKind(kind);
              if (kind.needsMedia) _pickMedia(kind);
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          if (state.kind.needsMedia) ...[
            _MediaBlock(
              kind: state.kind,
              mediaUrl: state.mediaUrl,
              fileName: state.fileName,
              uploading: state.uploading,
              onPick: () => _pickMedia(state.kind),
              onClear: _notifier.clearMedia,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Your Message (Optional)',
              style: context.text.titleSmall?.copyWith(
                color: context.headlineBrandColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          TextField(
            controller: _message,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 6,
            maxLength: AddWishState.textMax,
            decoration: InputDecoration(
              hintText: state.kind == MemoryWishKind.text
                  ? 'Happy Birthday! 🎉 May your day be filled with love.'
                  : 'Say something…',
            ),
            onChanged: _notifier.setText,
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
              onPressed: state.canPreview && !state.uploading ? _preview : null,
              child: const Text('Preview Memory'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Which kind of wish this is. Four chips, because the four compose screens are
/// otherwise the same screen.
class _KindPicker extends StatelessWidget {
  const _KindPicker({required this.selected, required this.onSelect});

  final MemoryWishKind selected;
  final ValueChanged<MemoryWishKind> onSelect;

  static const _icons = {
    MemoryWishKind.photo: Icons.image_outlined,
    MemoryWishKind.text: Icons.edit_outlined,
    MemoryWishKind.audio: Icons.mic_none,
    MemoryWishKind.video: Icons.videocam_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (final kind in MemoryWishKind.values) ...[
          Expanded(
            child: InkWell(
              onTap: () => onSelect(kind),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: kind == selected ? colors.optionFill : colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: kind == selected ? colors.primary : colors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _icons[kind],
                      size: AppSizes.iconLg,
                      color: kind == selected
                          ? colors.primary
                          : colors.primaryMuted,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      switch (kind) {
                        MemoryWishKind.photo => 'Photo',
                        MemoryWishKind.text => 'Text',
                        MemoryWishKind.audio => 'Voice',
                        MemoryWishKind.video => 'Video',
                      },
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: kind == selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (kind != MemoryWishKind.values.last)
            const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// The picked file, with the ✕ the frames put in its top-right corner.
class _MediaBlock extends StatelessWidget {
  const _MediaBlock({
    required this.kind,
    required this.mediaUrl,
    required this.fileName,
    required this.uploading,
    required this.onPick,
    required this.onClear,
  });

  final MemoryWishKind kind;
  final String? mediaUrl;
  final String? fileName;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onClear;

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
