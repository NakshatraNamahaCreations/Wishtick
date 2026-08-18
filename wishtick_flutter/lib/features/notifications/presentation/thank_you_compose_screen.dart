import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../memories/presentation/widgets/memory_players.dart';
import '../domain/thank_you_note.dart';
import 'notification_providers.dart';
import 'thank_you_controller.dart';
import 'widgets/thank_you_kind_sheet.dart';

/// The thank-you compose screens — "Write Message" (`2209:104`), "Photo
/// Message" (`2015:271`), "Video Message" (`2015:382`), and the voice note
/// inferred from the same pair.
///
/// One screen for all four: the frames differ only in the header, whether an
/// attachment sits above the message box, and whether the message is required.
/// The kind is chosen in the sheet at `2012:109` before arriving here, and can
/// be changed from the header.
class ThankYouComposeScreen extends ConsumerStatefulWidget {
  const ThankYouComposeScreen({required this.noteId, super.key});

  final String noteId;

  @override
  ConsumerState<ThankYouComposeScreen> createState() =>
      _ThankYouComposeScreenState();
}

class _ThankYouComposeScreenState extends ConsumerState<ThankYouComposeScreen> {
  TextEditingController? _message;
  bool _askedForKind = false;
  bool _seededMessage = false;

  @override
  void dispose() {
    _message?.dispose();
    super.dispose();
  }

  ThankYouController get _notifier =>
      ref.read(thankYouDraftProvider(widget.noteId).notifier);

  /// Fills the box with the server's draft the first time it arrives.
  ///
  /// Seeding on the first build is not enough and was the bug the device
  /// found: the note is still loading then, so the controller was created
  /// empty and never updated — the box showed its hint while the counter
  /// reported the drafted body's length. The flag keeps the user's own typing
  /// from being overwritten by a later rebuild.
  void _seedMessage(ThankYouDraft draft) {
    _message ??= TextEditingController(text: draft.message);
    if (_seededMessage || draft.message.isEmpty) return;
    _seededMessage = true;
    _message!.text = draft.message;
  }

  /// Opens the kind sheet once, the first time an untouched text note lands
  /// here — the design's flow is arrival → sheet → compose, and a note the
  /// server drafted is always `text` until the user chooses.
  void _maybeAskForKind(ThankYouNote note) {
    if (_askedForKind ||
        note.kind != ThankYouKind.text ||
        note.mediaUrl != null) {
      return;
    }
    _askedForKind = true;
    Future.microtask(() async {
      if (!mounted) return;
      final kind = await showThankYouKindSheet(context);
      if (kind != null) _notifier.setKind(kind);
    });
  }

  Future<void> _pickMedia(ThankYouKind kind) async {
    final picker = ImagePicker();
    final XFile? picked = switch (kind) {
      ThankYouKind.photo => await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
      ),
      ThankYouKind.video => await picker.pickVideo(source: ImageSource.gallery),
      // No recorder is bundled, so a voice note is picked as a file the same
      // way a memory wish is — see `add_wish_screen.dart`.
      ThankYouKind.audio => await picker.pickMedia(),
      ThankYouKind.text => null,
    };
    if (picked == null) return;

    _notifier.setUploading(true);
    try {
      final media = await ref
          .read(mediaRepositoryProvider)
          .uploadFile(
            file: picked,
            purpose: MediaPurpose.thankYou,
            fileName: picked.name,
          );
      _notifier.setMedia(mediaId: media.id, localPath: picked.path);
    } catch (_) {
      _notifier.fail('Could not upload that file.');
    } finally {
      _notifier.setUploading(false);
    }
  }

  Future<void> _preview() async {
    final saved = await _notifier.saveDraft();
    if (!saved || !mounted) return;
    await context.push<void>(AppRoutes.thankYouPreview(widget.noteId));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final note = ref.watch(thankYouNoteProvider(widget.noteId));
    final draft = ref.watch(thankYouDraftProvider(widget.noteId));

    note.whenData(_maybeAskForKind);
    _seedMessage(draft);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: _titleOf(draft.kind)),
      body: note.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                if (draft.kind.needsMedia) ...[
                  _Attachment(
                    draft: draft,
                    onAdd: () => unawaited(_pickMedia(draft.kind)),
                    onRemove: _notifier.clearMedia,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Your Message (Optional)',
                    style: context.text.titleMedium?.copyWith(
                      color: context.headlineBrandColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _MessageBox(
                  controller: _message!,
                  value: draft.message,
                  onChanged: (value) {
                    _notifier.setMessage(value);
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                // A different kind is one tap away rather than a back-and-
                // reopen: the sheet only shows automatically the first time.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => unawaited(_changeKind()),
                    icon: const Icon(Icons.swap_horiz, size: AppSizes.iconMd),
                    label: const Text('Change how you thank them'),
                  ),
                ),
                if (draft.error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  WishtickErrorText(draft.error!),
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
              onPressed: draft.canPreview && !draft.busy && !draft.uploading
                  ? () => unawaited(_preview())
                  : null,
              child: Text(
                draft.kind == ThankYouKind.text
                    ? 'Preview Message'
                    : 'Preview Thank You',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeKind() async {
    final kind = await showThankYouKindSheet(context);
    if (kind != null) _notifier.setKind(kind);
  }

  static String _titleOf(ThankYouKind kind) => switch (kind) {
    ThankYouKind.text => 'Write Message',
    ThankYouKind.photo => 'Photo Message',
    ThankYouKind.audio => 'Voice Note',
    ThankYouKind.video => 'Video Message',
  };
}

/// The attachment slot: the picked file with a close badge, or an add tile.
class _Attachment extends StatelessWidget {
  const _Attachment({
    required this.draft,
    required this.onAdd,
    required this.onRemove,
  });

  final ThankYouDraft draft;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final local = draft.mediaLocalPath;
    final url = draft.mediaUrl;
    final hasMedia = local != null || url != null;

    if (draft.uploading) {
      return AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!hasMedia) {
      return _AddTile(kind: draft.kind, onTap: onAdd);
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: _Preview(draft: draft),
        ),
        Positioned(
          top: AppSpacing.md,
          right: AppSpacing.md,
          child: Material(
            color: colors.overlay,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.close, size: 20, color: colors.textOnDark),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws whichever player the kind calls for, from the local file when there
/// is one and the uploaded URL otherwise.
class _Preview extends StatelessWidget {
  const _Preview({required this.draft});

  final ThankYouDraft draft;

  @override
  Widget build(BuildContext context) {
    final local = draft.mediaLocalPath;
    final url = draft.mediaUrl;

    return switch (draft.kind) {
      ThankYouKind.photo => AspectRatio(
        aspectRatio: 1,
        child: local != null
            ? Image.file(File(local), fit: BoxFit.cover)
            : Image.network(url!, fit: BoxFit.cover),
      ),
      // The players stream from a URL, so a just-picked file plays only after
      // it has uploaded — which it always has by the time this draws.
      ThankYouKind.video => MemoryVideoPlayer(url: url ?? local!),
      ThankYouKind.audio => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: MemoryAudioPlayer(url: url ?? local!),
      ),
      ThankYouKind.text => const SizedBox.shrink(),
    };
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.kind, required this.onTap});

  final ThankYouKind kind;
  final VoidCallback onTap;

  String get _label => switch (kind) {
    ThankYouKind.photo => 'Add Photo',
    ThankYouKind.video => 'Add Video',
    ThankYouKind.audio => 'Add Voice Note',
    ThankYouKind.text => '',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.add, color: colors.textPrimary),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _label,
          style: context.text.bodySmall?.copyWith(color: colors.textPrimary),
        ),
      ],
    );
  }
}

/// The white message box with the `40/100` counter in its lower-right.
class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.controller,
    required this.value,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: 5,
            maxLength: ThankYouDraft.messageMax,
            textCapitalization: TextCapitalization.sentences,
            // The box *is* the field's chrome, so the field draws none.
            buildCounter: _noCounter,
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: 'Write a heartfelt message',
            ),
          ),
          Text(
            '${value.characters.length}/${ThankYouDraft.messageMax}',
            style: context.text.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;
