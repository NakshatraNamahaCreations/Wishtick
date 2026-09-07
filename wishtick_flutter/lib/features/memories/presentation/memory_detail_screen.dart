import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/share/share_messages.dart' as messages;
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/memory.dart';
import 'memory_providers.dart';
import 'reply_controller.dart';
import 'widgets/memory_cards.dart';
import 'widgets/wish_preview_card.dart';

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
  Future<void> _share(MemoryCapsule capsule) async {
    final url = capsule.share?.url;
    if (url == null) return;
    await SharePlus.instance.share(
      ShareParams(
        text: messages
            .memoryContribute(
              title: capsule.title,
              unlockAt: capsule.unlockAt,
              slug: capsule.share!.slug,
              personName: capsule.personName,
              senderName: ref.read(sessionProvider).user?.name,
            )
            .combined,
        subject: capsule.title,
      ),
    );
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
                  // Straight to "How would you like to add the wish?" — the
                  // kind is chosen first now, so the compose screen no longer
                  // has to offer it again.
                  onPressed: () =>
                      context.push<void>(AppRoutes.memoryWishKind(memory.id)),
                  child: Text(
                    memory.hasContributed ? 'Add Another Wish' : 'Add a Wish',
                  ),
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
            // Reading back your own wishes, rather than forcing the capsule
            // open to check what is in it. "Open it now" used to sit here: it
            // revealed everyone's wishes to everyone, immediately and
            // irreversibly, which is a heavy price for "what did I write?".
            if (!memory.isOpen && memory.hasContributed) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      context.push<void>(AppRoutes.memoryMyWishes(memory.id)),
                  child: Text(
                    memory.myWishCount == 1
                        ? 'Preview my wish'
                        : 'Preview my ${memory.myWishCount} wishes',
                  ),
                ),
              ),
            ],
            // Only once it has opened, and only for the person it was for:
            // there is nothing to answer until the wishes are readable, and
            // nobody else is being written to.
            if (memory.isOpen && memory.isRecipient) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      context.push<void>(AppRoutes.memoryReplyKind(memory.id)),
                  child: const Text('Reply to everyone'),
                ),
              ),
            ],

            _RepliesSection(memoryId: memory.id),
          ],
        ),
      ),
    );
  }
}

/// The replies hanging off this memory.
///
/// Renders nothing at all when there are none — including while it is loading
/// and if the fetch fails. A heading over an empty space would ask the reader to
/// wonder what is missing, and this is a secondary panel on somebody else's
/// screen: it earns its space only when it has something in it.
class _RepliesSection extends ConsumerWidget {
  const _RepliesSection({required this.memoryId});

  final String memoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replies = ref.watch(memoryRepliesProvider(memoryId)).value;
    if (replies == null || replies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.section),
        Text(
          replies.length == 1 ? 'A reply' : '${replies.length} replies',
          style: context.text.titleSmall?.copyWith(
            color: context.headlineBrandColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final reply in replies) ...[
          _ReplyCard(reply: reply),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// One reply: who wrote it, what they attached, and what they said.
class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply});

  final MemoryReply reply;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.isMine
                ? (reply.recipientCount == 1
                      ? 'You replied'
                      : 'You replied to ${reply.recipientCount} people')
                : reply.authorName,
            style: context.text.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (reply.mediaUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            WishPreviewCard(
              kind: reply.kind,
              mediaUrl: reply.mediaUrl,
              text: '',
            ),
          ],
          if (reply.text != null && reply.text!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              reply.text!,
              style: context.text.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
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
