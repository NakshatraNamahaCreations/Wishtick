import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../data/memories_repository.dart';
import '../domain/memory.dart';
import 'memory_providers.dart';
import 'widgets/memory_cards.dart';

/// A capsule while it is still sealed — the countdown, who has contributed, and
/// the two things the host can do about it.
///
/// **Inferred, not matched.** No frame covers this screen: the Sprint 8 exports
/// go straight from creating a capsule to adding a wish to the opened story.
/// Everything on it is built from patterns the matched screens already use.
class MemoryDetailScreen extends ConsumerStatefulWidget {
  const MemoryDetailScreen({required this.memoryId, super.key});

  final String memoryId;

  @override
  ConsumerState<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
  bool _busy = false;

  Future<void> _share(MemoryCapsule capsule) async {
    final url = capsule.share?.url;
    if (url == null) return;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Add a wish to ${capsule.title} — it opens for '
            '${capsule.personName} on '
            '${DateFormat('d MMM').format(capsule.unlockAt.toLocal())}.\n$url',
        subject: capsule.title,
      ),
    );
  }

  Future<void> _unlockNow(MemoryCapsule capsule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Open it now?'),
        content: Text(
          'Everyone will be able to read all ${capsule.wishCount} '
          '${capsule.wishCount == 1 ? 'wish' : 'wishes'} straight away, and '
          'nobody can add another. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Open now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(memoriesRepositoryProvider).unlockNow(widget.memoryId);
      ref.invalidate(memoryProvider(widget.memoryId));
      ref.invalidate(myMemoriesProvider);
      if (!mounted) return;
      context.go(AppRoutes.memoryExperience(widget.memoryId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open it. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final capsule = ref.watch(memoryProvider(widget.memoryId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context),
      body: capsule.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: WishtickErrorText('Could not load it.')),
        data: (memory) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            if (memory.coverUrl != null) ...[
              SizedBox(
                height: 180,
                width: double.infinity,
                child: WishtickImage(
                  url: memory.coverUrl,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              memory.title,
              style: context.text.displaySmall?.copyWith(
                color: context.headlineBrandColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'For ${memory.personName}',
              style: context.text.bodyLarge?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            if (memory.description != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                memory.description!,
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Align(
              alignment: Alignment.centerLeft,
              child: MemoryCountdownChip(capsule: memory),
            ),
            const SizedBox(height: AppSpacing.xl),

            _SealedPanel(capsule: memory),

            const SizedBox(height: AppSpacing.xl),
            if (!memory.isOpen)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      context.push<void>(AppRoutes.memoryAddWish(memory.id)),
                  child: const Text('Add a Wish'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      context.push<void>(AppRoutes.memoryExperience(memory.id)),
                  child: const Text('Open the Memory'),
                ),
              ),

            if (memory.isHost && memory.share != null) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _share(memory),
                  child: const Text('Invite people to add a wish'),
                ),
              ),
            ],
            if (memory.isHost && !memory.isOpen) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _busy ? null : () => _unlockNow(memory),
                  child: const Text('Open it now'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What is safe to say about a sealed capsule: how many wishes, and who wrote
/// them. Never what they say — that is the time-lock, and the server does not
/// send it.
class _SealedPanel extends StatelessWidget {
  const _SealedPanel({required this.capsule});

  final MemoryCapsule capsule;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                capsule.isOpen ? Icons.lock_open : Icons.lock_outline,
                size: AppSizes.iconMd,
                color: colors.primaryMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${capsule.wishCount} '
                '${capsule.wishCount == 1 ? 'Wish' : 'Wishes'}',
                style: context.text.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            capsule.isOpen
                ? 'Opened ${DateFormat('d MMM yyyy').format(capsule.unlockAt.toLocal())}.'
                : 'Sealed until '
                      '${DateFormat('d MMM yyyy, h:mm a').format(capsule.unlockAt.toLocal())}. '
                      'Nobody can read what is inside until then — not even you.',
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (capsule.contributors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'From ${capsule.contributors.join(', ')}',
              style: context.text.bodyMedium?.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
