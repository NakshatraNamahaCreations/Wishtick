import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../domain/memory.dart';
import 'add_wish_controller.dart';
import 'memory_providers.dart';
import 'widgets/wish_preview_card.dart';

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
          WishPreviewCard(
            kind: state.kind,
            mediaUrl: state.mediaUrl,
            text: state.text,
          ),
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
