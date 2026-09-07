import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// For XFile, which MediaRepository takes. cross_file is not a direct
// dependency; image_picker re-exports it and is.
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_limits.dart';
import '../../../core/media/media_probe.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../domain/memory.dart';
import 'reply_controller.dart';
import 'widgets/wish_media_block.dart';

/// Composing a reply to a memory — the same screen as the wish composer, in the
/// same four kinds, pointed the other way.
///
/// The media goes up here rather than at send time, unlike the create-a-memory
/// wizard. There is nothing speculative left at this point: the capsule already
/// exists and has opened, so a reply that is abandoned after the upload costs
/// one orphaned file, against the cost of making somebody wait on a video
/// transcode while a recipient list is on screen.
class ReplyComposeScreen extends ConsumerStatefulWidget {
  const ReplyComposeScreen({required this.memoryId, super.key});

  /// The memory being replied to. Decides who is preselected on the next step.
  final String memoryId;

  @override
  ConsumerState<ReplyComposeScreen> createState() => _ReplyComposeScreenState();
}

class _ReplyComposeScreenState extends ConsumerState<ReplyComposeScreen> {
  late final _message = TextEditingController(
    text: ref.read(replyProvider).text,
  );

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  ReplyController get _notifier => ref.read(replyProvider.notifier);

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

    if (!limit.accepts(file.size)) {
      _notifier.fail(
        'That ${kind.label.toLowerCase()} is larger than ${limit.label}. '
        'Pick a smaller one.',
      );
      return;
    }

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
            purpose: MediaPurpose.memoryReply,
            // XFile.fromData drops `name` on io, so the real one has to be
            // handed over separately or a .m4a uploads as a JPEG.
            fileName: file.name,
          );
      _notifier.setMedia(
        mediaId: media.id,
        mediaUrl: media.url,
        fileName: file.name,
      );
    } catch (_) {
      _notifier.fail('Could not upload that file. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(replyProvider);
    final limit = mediaLimitsOr(ref).forPurpose(MediaPurpose.memoryReply);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'Your reply'),
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
              onPick: () => unawaited(_pickMedia(state.kind, limit)),
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
            maxLength: ReplyState.textMax,
            decoration: InputDecoration(
              hintText: state.kind == MemoryWishKind.text
                  ? 'Thank you all so much — this made my day.'
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
              onPressed: state.composed && !state.uploading
                  ? () => unawaited(
                      context.push<void>(
                        AppRoutes.memoryReplyRecipients(widget.memoryId),
                      ),
                    )
                  : null,
              child: const Text('Choose who to send it to'),
            ),
          ),
        ),
      ),
    );
  }
}
