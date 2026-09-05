import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// For XFile, which MediaRepository takes. cross_file is not a direct
// dependency; image_picker re-exports it and is.
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../data/events_repository.dart';
import 'create_event_controller.dart';
import 'event_providers.dart';

/// The four kinds of file `2248:70` offers.
enum _UploadKind {
  image('Upload Image', 'JPG, PNG', ['jpg', 'jpeg', 'png', 'webp', 'heic']),
  gif('GIF', 'GIF', ['gif']),
  video('Video', 'MP4', ['mp4']),
  pdf('Upload PDF', 'PDF', ['pdf']);

  const _UploadKind(this.title, this.blurb, this.extensions);

  final String title;
  final String blurb;
  final List<String> extensions;
}

/// The server's own cap for `event_invite` media. Enforced here too so a host
/// with a 40 MB video is told before the bytes go up the wire, not after.
const _kMaxBytes = 10 * 1024 * 1024;

/// "Upload Invitation" (`2248:70`).
class UploadInvitationScreen extends ConsumerStatefulWidget {
  const UploadInvitationScreen({this.eventId, super.key});

  /// Null while the event is still being created: the file waits in the
  /// wizard and goes up with the event once the host has seen the preview.
  final String? eventId;

  @override
  ConsumerState<UploadInvitationScreen> createState() =>
      _UploadInvitationScreenState();
}

class _UploadInvitationScreenState
    extends ConsumerState<UploadInvitationScreen> {
  _UploadKind _kind = _UploadKind.image;
  PlatformFile? _picked;
  bool _busy = false;
  String? _error;

  Future<void> _pick(_UploadKind kind) async {
    setState(() {
      _kind = kind;
      _error = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kind.extensions,
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null || !mounted) return;
    if (file.size > _kMaxBytes) {
      setState(() {
        _picked = null;
        _error = 'That file is larger than 10 MB.';
      });
      return;
    }
    setState(() => _picked = file);
  }

  Future<void> _next() async {
    final file = _picked;
    final bytes = file?.bytes;
    if (file == null || bytes == null || _busy) return;

    final eventId = widget.eventId;
    if (eventId == null) {
      // Nothing to attach it to yet, so nothing goes up: the wizard keeps the
      // bytes, and the preview's button uploads them with the event.
      ref.read(createEventProvider.notifier).setInvitation(bytes, file.name);
      await context.push<void>(AppRoutes.createEventInvitePreview);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final media = await ref
          .read(mediaRepositoryProvider)
          .uploadFile(
            file: XFile.fromData(bytes, name: file.name),
            purpose: MediaPurpose.eventInvite,
            // XFile.fromData drops `name` on io — without this a PDF or an
            // MP4 invitation uploads as a JPEG.
            fileName: file.name,
          );
      await ref
          .read(eventsRepositoryProvider)
          .update(eventId, inviteMediaId: media.id);
      ref.invalidate(eventDetailProvider(eventId));
      if (!mounted) return;
      await context.push<void>(AppRoutes.eventInvitePreview(eventId));
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not upload that file. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final picked = _picked;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'Upload Invitation'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            'Choose the type of file you want to upload',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          for (final kind in _UploadKind.values) ...[
            _KindCard(
              kind: kind,
              selected: kind == _kind,
              onTap: _busy ? null : () => _pick(kind),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: AppSizes.iconMd,
                color: colors.primaryMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Supported document JPG, PNG, GIF, MP4, PDF upto 10 MB',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.primaryMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (picked != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: AppSizes.iconMd,
                  color: colors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    picked.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            WishtickErrorText(_error!),
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
              onPressed: picked == null || _busy ? null : _next,
              child: _busy
                  ? SizedBox(
                      width: AppSizes.iconMd,
                      height: AppSizes.iconMd,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Text('Next'),
            ),
          ),
        ),
      ),
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final _UploadKind kind;
  final bool selected;
  final VoidCallback? onTap;

  static const _icons = {
    _UploadKind.image: Icons.image_outlined,
    _UploadKind.gif: Icons.gif_box_outlined,
    _UploadKind.video: Icons.movie_outlined,
    _UploadKind.pdf: Icons.picture_as_pdf_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(
                _icons[kind] ?? Icons.insert_drive_file_outlined,
                size: AppSizes.iconLg + AppSpacing.sm,
                color: colors.primaryMuted,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.title,
                      style: context.text.titleSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      kind.blurb,
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
