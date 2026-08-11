import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../domain/memory.dart';
import 'memory_providers.dart';
import 'widgets/memory_cards.dart';

/// The Memories tab (`4104:1433`).
///
/// Four bands: the plum hero, the circles of what has already opened, and three
/// carousels — everything upcoming, what you made, what you contributed to.
class MemoriesTabScreen extends ConsumerWidget {
  const MemoriesTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final mine = ref.watch(myMemoriesProvider);
    final contributed = ref.watch(contributedMemoriesProvider);
    final unlocked = ref.watch(unlockedMemoriesProvider);
    final upcoming = ref.watch(upcomingMemoriesProvider);

    final failed = mine.hasError && contributed.hasError;
    final loading = mine.isLoading && contributed.isLoading;

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myMemoriesProvider);
          ref.invalidate(contributedMemoriesProvider);
          await ref.read(myMemoriesProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const _Hero(),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.huge),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (failed)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.huge),
                child: Center(
                  child: WishtickErrorText('Could not load your memories.'),
                ),
              )
            else ...[
              _UnlockedRow(capsules: unlocked.value ?? const []),
              _Carousel(
                title: 'Upcoming Unlocks',
                capsules: upcoming.value ?? const [],
                emptyLine: 'Nothing sealed just yet.',
              ),
              _Carousel(
                title: 'Created By You',
                capsules: mine.value ?? const [],
                emptyLine: 'Create a memory and invite people to fill it.',
              ),
              _Carousel(
                title: 'Contributed By You',
                capsules: contributed.value ?? const [],
                emptyLine:
                    'Wishes you add to other people’s memories land here.',
              ),
            ],
            const SizedBox(height: AppSpacing.huge),
          ],
        ),
      ),
    );
  }
}

/// The plum banner: "Every wish locked with Love".
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.primaryDeep,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.sheet),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Every wish locked with Love',
              textAlign: TextAlign.center,
              style: context.text.displaySmall?.copyWith(
                color: colors.textOnDark,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Create a memory, invite loved ones and surprise them on the '
              'special day.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: colors.textOnDark.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The circles of capsules that have already opened.
class _UnlockedRow extends StatelessWidget {
  const _UnlockedRow({required this.capsules});

  final List<MemoryCapsule> capsules;

  @override
  Widget build(BuildContext context) {
    if (capsules.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BandHeading('Unlocked Memories'),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: capsules.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) => UnlockedMemoryAvatar(
              capsule: capsules[i],
              // Straight into the story — an opened capsule's whole point.
              onTap: () => context.push<void>(
                AppRoutes.memoryExperience(capsules[i].id),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One titled band of capsule cards.
class _Carousel extends StatelessWidget {
  const _Carousel({
    required this.title,
    required this.capsules,
    required this.emptyLine,
  });

  final String title;
  final List<MemoryCapsule> capsules;
  final String emptyLine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BandHeading(title),
        if (capsules.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Text(
              emptyLine,
              style: context.text.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          )
        else
          SizedBox(
            height: MemoryCard.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: capsules.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, i) => MemoryCard(
                capsule: capsules[i],
                // Sealed capsules go to their detail; open ones to the story.
                onTap: () => context.push<void>(
                  capsules[i].isOpen
                      ? AppRoutes.memoryExperience(capsules[i].id)
                      : AppRoutes.memory(capsules[i].id),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BandHeading extends StatelessWidget {
  const _BandHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xxl,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    child: Text(
      text,
      style: context.text.titleLarge?.copyWith(
        color: context.colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
