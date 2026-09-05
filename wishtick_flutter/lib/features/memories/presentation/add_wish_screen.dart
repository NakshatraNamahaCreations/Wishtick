import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// For XFile, which MediaRepository takes. cross_file is not a direct
// dependency; image_picker re-exports it and is.
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_limits.dart';
import '../../../core/media/media_probe.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../domain/memory.dart';
import 'add_wish_controller.dart';
import 'memory_wish_preview_screen.dart';
import 'widgets/wish_media_block.dart';

/// Composing a wish — `2073:55` (photo), `2078:233` (text), `2074:129` (video),
/// and the voice note.
///
/// One screen for all four kinds rather than four: the frames are identical
/// below the media block, down to the "Your Message (Optional)" label and the
/// 40/100 counter.
///
/// Reached from [ChooseWishKindScreen], which is where the kind is picked. This
/// screen used to carry a row of four chips to switch between them, which asked
/// the same question twice — and let someone undo, one tap later, the choice
/// the previous screen exists to make.
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

  Future<void> _pickMedia(MemoryWishKind kind, PurposeLimit limit) async {
    final extensions = wishMediaExtensions(kind);
    if (extensions.isEmpty) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;

    // Before the bytes go up, not after the server has taken them and refused.
    if (!limit.accepts(file.size)) {
      _notifier.fail(
        'That ${kind.label.toLowerCase()} is larger than ${limit.label}. '
        'Pick a smaller one.',
      );
      return;
    }

    // Length is checked from the file on disk, so it costs nothing if it fails
    // — unlike the server's check, which can only run once the clip has been
    // uploaded and encoded. An unreadable probe returns null and is allowed
    // through rather than blocking a clip this device merely cannot decode.
    final path = file.path;
    if (path != null && limit.maxDurationSeconds != null) {
      final length = await ref.read(mediaDurationProbeProvider)(path);
      if (!mounted) return;
      if (length != null && !limit.acceptsDuration(length)) {
        _notifier.fail(
          'That ${kind.label.toLowerCase()} runs ${length.inSeconds}s. '
          'Keep it under ${limit.durationLabel}.',
        );
        return;
      }
    }

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
    final limit = mediaLimitsOr(ref).forPurpose(MediaPurpose.memoryWish);

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
          if (state.kind.needsMedia) ...[
            WishMediaBlock(
              kind: state.kind,
              mediaUrl: state.mediaUrl,
              fileName: state.fileName,
              uploading: state.uploading,
              sizeLimit: wishMediaHint(state.kind, limit),
              onPick: () => _pickMedia(state.kind, limit),
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
