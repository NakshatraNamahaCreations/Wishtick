import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../data/group_gift_repository.dart';
import '../domain/group_gift.dart';

/// The invitations waiting on the caller's answer.
///
/// A group gift is only reachable through the wishlist it hangs off, and on a
/// private list an outsider cannot see it at all — so a share link is no way to
/// bring a friend in. An invitation is: accepting it grants the wishlist access
/// that joining needs.
final groupGiftInvitesProvider = FutureProvider<List<GroupGiftInvite>>((ref) {
  return ref.watch(groupGiftRepositoryProvider).listInvites();
});

class GroupGiftInvitesScreen extends ConsumerWidget {
  const GroupGiftInvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final invites = ref.watch(groupGiftInvitesProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'Group Gift Invites'),
      // Error before loading: Riverpod retries a failed provider, so a provider
      // that has failed is also loading — matching `hasValue: false` first
      // would spin forever on a dead network.
      body: switch (invites) {
        AsyncValue(hasError: true, hasValue: false) => _Empty(
          text: 'Could not load your invitations.',
          onRetry: () => ref.invalidate(groupGiftInvitesProvider),
        ),
        AsyncValue(hasValue: false) => const Center(
          child: CircularProgressIndicator(),
        ),
        AsyncValue(:final value?) when value.isEmpty => const _Empty(
          text: 'No invitations right now.',
        ),
        AsyncValue(:final value?) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => _InviteRow(invite: value[index]),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

/// A summary that opens the invitation rather than answering it.
///
/// Accept and Decline live on the detail screen now: saying yes commits money
/// and access, and a row that offers both while showing only a title asks
/// people to answer a question they have not been told.
class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.invite});

  final GroupGiftInvite invite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            unawaited(context.push<void>(AppRoutes.groupGiftInvite(invite.id))),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppSizes.avatarSm / 2,
                backgroundColor: colors.background,
                child: Text(
                  invite.inviterName.characters.first.toUpperCase(),
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.groupTitle,
                      style: context.text.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      // Who asked, not just that somebody did.
                      '${invite.inviterName} asked you to chip in',
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );
}
