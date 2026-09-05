import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../data/memories_repository.dart';
import '../domain/memory.dart';
import 'widgets/wish_preview_card.dart';

/// What the viewer themselves put in a capsule, readable while it is sealed.
///
/// This is what replaced "Open it now". That button answered a fair question —
/// *what did I write?* — at an unreasonable price: it opened the capsule for
/// everybody at once, immediately and irreversibly, and stopped anyone adding
/// another wish. Reading back your own words answers the same question and
/// costs nothing, because nobody is surprised by their own message.
///
/// Only ever the caller's own wishes. The time-lock stays literally true: no
/// other person's wish is readable a moment early, and the sealed panel's
/// promise that nobody can read what is inside still holds.
class MyWishesScreen extends ConsumerWidget {
  const MyWishesScreen({required this.memoryId, super.key});

  final String memoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final wishes = ref.watch(myWishesProvider(memoryId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'Your wishes'),
      body: SafeArea(
        child: wishes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Center(
              child: WishtickErrorText('Could not load your wishes.'),
            ),
          ),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Center(
                    child: Text(
                      'You have not added a wish to this memory yet.',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.xl),
                  itemBuilder: (context, index) {
                    final wish = list[index];
                    return WishPreviewCard(
                      kind: wish.kind,
                      mediaUrl: wish.mediaUrl,
                      text: wish.text ?? '',
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// The caller's own wishes on one capsule.
///
/// Its own provider rather than a filter over the capsule's `wishes`, because
/// that list is empty until the memory opens — the whole point here is to read
/// something the time-lock hides.
final myWishesProvider = FutureProvider.family<List<MemoryWish>, String>((
  ref,
  memoryId,
) {
  return ref.watch(memoriesRepositoryProvider).myWishes(memoryId);
});
