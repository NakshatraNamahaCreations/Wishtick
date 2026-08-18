import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../../memories/presentation/widgets/memory_players.dart';
import '../domain/thank_you_note.dart';
import 'notification_providers.dart';
import 'thank_you_controller.dart';

/// "Preview" (`2209:141`, `2227:146`, `2209:156`) — the note exactly as it will
/// reach the gifter, with one button to send it.
///
/// Reads the *saved* note rather than the local draft: the compose screen
/// writes the draft before pushing here, so what is previewed is what the
/// server holds — the one thing that can actually be sent.
class ThankYouPreviewScreen extends ConsumerWidget {
  const ThankYouPreviewScreen({required this.noteId, super.key});

  final String noteId;

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final sent = await ref.read(thankYouDraftProvider(noteId).notifier).send();
    if (!sent || !context.mounted) return;
    context.pushReplacement(AppRoutes.thankYouSent(noteId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final note = ref.watch(thankYouNoteProvider(noteId));
    final draft = ref.watch(thankYouDraftProvider(noteId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'Preview'),
      body: note.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: WishtickErrorText('Could not load this thank-you.'),
          ),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            _Card(note: value),
            if (draft.error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              WishtickErrorText(draft.error!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: draft.busy || note.value?.status == ThankYouStatus.sent
                  ? null
                  : () => unawaited(_send(context, ref)),
              child: Text(
                note.value?.status == ThankYouStatus.sent
                    ? 'Already Sent'
                    : 'Send Thank You',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The white card: the attachment on top, the message beneath.
class _Card extends StatelessWidget {
  const _Card({required this.note});

  final ThankYouNote note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = note.mediaUrl;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (url != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: switch (note.kind) {
                ThankYouKind.photo => AspectRatio(
                  aspectRatio: 1,
                  child: WishtickImage(url: url),
                ),
                ThankYouKind.video => MemoryVideoPlayer(url: url),
                ThankYouKind.audio => Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: MemoryAudioPlayer(url: url),
                ),
                ThankYouKind.text => const SizedBox.shrink(),
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Text(
              note.body,
              style: context.text.bodyLarge?.copyWith(
                color: colors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
