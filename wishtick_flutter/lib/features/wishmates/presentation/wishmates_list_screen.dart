import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../domain/wishmate.dart';
import 'widgets/person_row.dart';
import 'wishmate_actions.dart';
import 'wishmates_providers.dart';

/// "WishMates" (`4177:138`) — the accepted connections, under a banner
/// counting the requests still waiting.
///
/// The banner is the only route to the WishLink tabs the frame draws, which is
/// why it stays on screen at zero and simply stops being a link: a row that
/// vanishes takes its own navigation with it.
class WishmatesListScreen extends ConsumerWidget {
  const WishmatesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final mates = ref.watch(wishmatesProvider);
    final pending = ref.watch(pendingRequestCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(
        context,
        title: 'WishMates',
        // The only way into people search. `4177:42` is drawn as a pushed
        // screen and no frame says what pushes it — but a list whose empty
        // state tells you to search for someone has to offer a way to, and
        // this is the screen you are on when you want another WishMate.
        actions: [
          IconButton(
            onPressed: () => unawaited(context.push(AppRoutes.peopleSearch)),
            icon: Icon(Icons.person_search, color: colors.textPrimary),
            tooltip: 'Find people',
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => invalidateWishmateGraph(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: [
            const WishmateSectionTitle('Friend Requests'),
            _RequestsBanner(count: pending),
            const SizedBox(height: AppSpacing.xxl),
            WishmateSectionTitle(
              mates.hasValue
                  ? 'My WishMates (${mates.requireValue.length})'
                  : 'My WishMates',
            ),
            // Error before loading, and both before data. Riverpod 3 retries a
            // failed provider with a backoff, so a broken screen spends most of
            // its life *also* loading -- putting the spinner first would hide
            // every failure behind it for half a minute. `hasValue` guards the
            // error arm so a failed *refresh* keeps showing what we already
            // have rather than throwing it away.
            ...switch (mates) {
              AsyncValue(hasError: true, hasValue: false) => [
                _Message(
                  text: 'Could not load your WishMates.',
                  onRetry: () => ref.invalidate(wishmatesProvider),
                ),
              ],
              AsyncValue(hasValue: false) => const [
                Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              _ when mates.requireValue.isEmpty => const [
                _Message(
                  text:
                      'No WishMates yet. Search for someone by their @handle '
                      'to send your first WishLink.',
                ),
              ],
              _ => [
                for (final mate in mates.requireValue) ...[
                  _MateRow(mate: mate),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            },
          ],
        ),
      ),
    );
  }
}

/// "2 New Requests" — a white card, unlike the outlined rows beneath it.
class _RequestsBanner extends StatelessWidget {
  const _RequestsBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = switch (count) {
      0 => 'No new requests',
      1 => '1 New Request',
      _ => '$count New Requests',
    };

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(context.push(AppRoutes.wishlinks)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Container(
                width: AppSizes.avatarSm,
                height: AppSizes.avatarSm,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primarySubtle,
                ),
                child: Icon(
                  Icons.person_add_alt,
                  size: AppSizes.iconMd,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: context.text.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colors.textSecondary,
                size: AppSizes.iconLg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One accepted WishMate, with the overflow menu the frame draws.
class _MateRow extends ConsumerWidget {
  const _MateRow({required this.mate});

  final Wishmate mate;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove WishMate?'),
        content: Text(
          'You and ${mate.name} will no longer be WishMates, and neither of '
          'you will be able to send new messages. Your conversation is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref.read(wishmateActionsProvider).remove(mate.userId);
    if (context.mounted) reportWishmateResult(context, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PersonRow(
      person: mate,
      onTap: () => unawaited(context.push(AppRoutes.person(mate.userId))),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: context.colors.textSecondary),
        tooltip: 'More for ${mate.name}',
        onSelected: (value) => switch (value) {
          'profile' => unawaited(context.push(AppRoutes.person(mate.userId))),
          'remove' => unawaited(_remove(context, ref)),
          _ => null,
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'profile', child: Text('View profile')),
          PopupMenuItem(value: 'remove', child: Text('Remove WishMate')),
        ],
      ),
    );
  }
}

/// Empty and error states — the frames draw neither, so these are the app's
/// own words, kept to one sentence and always offering a way forward.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xl),
    child: Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ],
    ),
  );
}
