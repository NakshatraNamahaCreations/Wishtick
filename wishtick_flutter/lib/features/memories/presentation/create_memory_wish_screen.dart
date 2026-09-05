import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/media_limits.dart';
import '../../../core/media/media_probe.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../domain/memory.dart';
import 'create_memory_controller.dart';
import 'widgets/wish_media_block.dart';

/// The host composing their own first wish, while the memory is still a draft.
///
/// The contributor's [AddWishScreen] is the same screen for someone adding to
/// a capsule that already exists. It cannot be reused as-is: it is keyed by a
/// memory id and posts on submit, and here there is no id yet — the capsule is
/// created at the end of the wizard, and this wish goes in with it. The parts
/// that are genuinely the same, the media block and the preview card, are
/// shared widgets rather than copies.
///
/// No kind picker at the top, unlike the contributor's screen: the kind was
/// chosen on the previous step, and offering it again would undo the question
/// that was just answered.
class CreateMemoryWishScreen extends ConsumerStatefulWidget {
  const CreateMemoryWishScreen({super.key});

  @override
  ConsumerState<CreateMemoryWishScreen> createState() =>
      _CreateMemoryWishScreenState();
}

class _CreateMemoryWishScreenState
    extends ConsumerState<CreateMemoryWishScreen> {
  late final _message = TextEditingController(
    text: ref.read(createMemoryProvider).wishText,
  );
  String? _uploadError;

  /// Same cap the contributor's compose screen uses — the frames both draw a
  /// "40/100" counter.
  static const _textMax = 100;

  CreateMemoryController get _notifier =>
      ref.read(createMemoryProvider.notifier);

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(MemoryWishKind kind, PurposeLimit limit) async {
    final extensions = wishMediaExtensions(kind);
    if (extensions.isEmpty) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      // Only the path is needed now; the bytes are read at upload time, so a
      // 50 MB clip is not held in memory for the rest of the wizard.
      withData: false,
    );
    final file = result?.files.firstOrNull;
    if (file == null || !mounted) return;

    // Refused here, where the file was chosen. The upload does not happen until
    // the host has set an unlock moment two screens later, so without this the
    // rejection arrives long after the choice that caused it — attached to a
    // date picker, which is not where anyone would look for it.
    if (!limit.accepts(file.size)) {
      setState(
        () => _uploadError =
            'That ${kind.label.toLowerCase()} is larger than ${limit.label}. '
            'Pick a smaller one.',
      );
      return;
    }

    final path = file.path;
    if (path == null) {
      setState(() => _uploadError = 'That file could not be read.');
      return;
    }

    if (!await _withinDuration(path, kind, limit)) return;

    // Kept, not uploaded. The memory is not real until the host sets its
    // unlock moment and confirms; sending bytes now would leave a file in
    // storage for every draft that is abandoned before then.
    setState(() => _uploadError = null);
    _notifier.setWishFile(path: path, name: file.name);
  }

  /// Whether a clip is short enough, complaining on screen if it is not.
  ///
  /// A probe that cannot read the file returns null, and an unknown length is
  /// allowed through: refusing there would block clips that are perfectly fine
  /// on a device whose decoder happens to be fussy about the container. The
  /// server measures it again after the encode, which is the check that holds.
  Future<bool> _withinDuration(
    String path,
    MemoryWishKind kind,
    PurposeLimit limit,
  ) async {
    if (limit.maxDurationSeconds == null) return true;

    final length = await ref.read(mediaDurationProbeProvider)(path);
    if (!mounted) return false;
    if (length == null || limit.acceptsDuration(length)) return true;

    setState(
      () => _uploadError =
          'That ${kind.label.toLowerCase()} runs ${_seconds(length)}. '
          'Keep it under ${limit.durationLabel}.',
    );
    return false;
  }

  /// "24s", "1m 04s" — the length in the shortest honest form.
  static String _seconds(Duration d) {
    final total = d.inSeconds;
    if (total < 60) return '${total}s';
    return '${total ~/ 60}m ${(total % 60).toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(createMemoryProvider);
    final kind = state.wishKind ?? MemoryWishKind.text;
    final limit = mediaLimitsOr(ref).forPurpose(MediaPurpose.memoryWish);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: kind.label),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          if (kind.needsMedia) ...[
            WishMediaBlock(
              kind: kind,
              mediaUrl: state.wishFilePath,
              fileName: state.wishFileName,
              uploading: false,
              sizeLimit: wishMediaHint(kind, limit),
              onPick: () => unawaited(_pickMedia(kind, limit)),
              onClear: _notifier.clearWishMedia,
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
            maxLength: _textMax,
            decoration: InputDecoration(
              hintText: kind == MemoryWishKind.text
                  ? 'Happy Birthday! 🎉 May your day be filled with love.'
                  : 'Say something…',
            ),
            onChanged: _notifier.setWishText,
          ),

          if (_uploadError != null) ...[
            const SizedBox(height: AppSpacing.lg),
            WishtickErrorText(_uploadError!),
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
              onPressed: state.wishReady
                  ? () => unawaited(
                      context.push<void>(AppRoutes.createMemoryWishPreview),
                    )
                  : null,
              child: const Text('Preview Memory'),
            ),
          ),
        ),
      ),
    );
  }
}
