import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../wishmates/presentation/widgets/person_avatar.dart';
import '../domain/memory.dart';
import 'create_memory_controller.dart';
import 'widgets/wish_preview_card.dart';

/// What the host's own first wish will look like, before the memory is sealed.
///
/// The contributor's preview closes by sending the wish; this one closes by
/// continuing to the unlock step, because there is nothing to send to yet —
/// the capsule is created at the end of the wizard and the wish goes in with
/// it.
class CreateMemoryWishPreviewScreen extends ConsumerWidget {
  const CreateMemoryWishPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(createMemoryProvider);
    final recipient = state.recipient;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(
        context,
        title: state.wishKind == MemoryWishKind.audio
            ? 'Audio Preview'
            : 'Preview',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          WishPreviewCard(
            kind: state.wishKind ?? MemoryWishKind.text,
            mediaUrl: state.wishFilePath,
            text: state.wishText,
          ),
          const SizedBox(height: AppSpacing.section),
          // "To <person> / <relation>" — the reassurance that it is going to
          // the right person. Read from the draft rather than a fetched
          // capsule, because there is no capsule yet.
          if (recipient != null)
            Row(
              children: [
                PersonAvatar(person: recipient),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'To',
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      recipient.name,
                      style: context.text.titleSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (state.relationLabel case final relation?)
                      Text(
                        relation,
                        style: context.text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  unawaited(context.push<void>(AppRoutes.createMemoryUnlock)),
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );
  }
}
