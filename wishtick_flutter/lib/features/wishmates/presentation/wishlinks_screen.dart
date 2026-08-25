import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/wishmate.dart';
import 'widgets/people_you_may_know.dart';
import 'widgets/person_avatar.dart';
import 'widgets/person_row.dart';
import 'widgets/wishmate_header.dart';
import 'wishmate_actions.dart';
import 'wishmates_providers.dart';

/// "WishLink" — Received (`4177:77`) and Sent (`4177:111`).
///
/// One screen with two tabs rather than two routes, because they are two
/// readings of the same pending rows: the split is direction, not state. What
/// differs is only what you can do about them — a request addressed to you can
/// be accepted or declined; one you sent can only be taken back.
class WishLinksScreen extends ConsumerStatefulWidget {
  const WishLinksScreen({this.initialTab = 0, super.key});

  /// 0 = Received, 1 = Sent.
  final int initialTab;

  @override
  ConsumerState<WishLinksScreen> createState() => _WishLinksScreenState();
}

class _WishLinksScreenState extends ConsumerState<WishLinksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    initialIndex: widget.initialTab,
    vsync: this,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final received = ref.watch(receivedWishLinksProvider);
    final sent = ref.watch(sentWishLinksProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          const WishmateHeader(title: 'WishLink'),
          TabBar(
            controller: _tabs,
            labelColor: colors.textPrimary,
            unselectedLabelColor: colors.textSecondary,
            indicatorColor: colors.primary,
            indicatorWeight: 2,
            dividerColor: colors.border,
            labelStyle: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: context.text.titleSmall,
            tabs: [
              Tab(text: 'Received (${received.value?.length ?? 0})'),
              Tab(text: 'Sent (${sent.value?.length ?? 0})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _LinkList(
                  links: received,
                  emptyText: 'No one is waiting on you right now.',
                  rowBuilder: (link) => _ReceivedCard(link: link),
                ),
                _LinkList(
                  links: sent,
                  emptyText: 'You have no requests waiting for an answer.',
                  rowBuilder: (link) => _SentRow(link: link),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tab's body: its rows, then the shared suggestions rail.
class _LinkList extends ConsumerWidget {
  const _LinkList({
    required this.links,
    required this.emptyText,
    required this.rowBuilder,
  });

  final AsyncValue<List<WishLink>> links;
  final String emptyText;
  final Widget Function(WishLink) rowBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => invalidateWishmateGraph(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          // See the note in `wishmates_list_screen.dart`: error before loading,
          // because Riverpod retries and would otherwise keep the spinner up.
          ...switch (links) {
            AsyncValue(hasError: true, hasValue: false) => [
              _Centered(
                text: 'Could not load your WishLinks.',
                onRetry: () => invalidateWishmateGraph(ref),
              ),
            ],
            AsyncValue(hasValue: false) => const [
              Padding(
                padding: EdgeInsets.only(top: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            _ when links.requireValue.isEmpty => [_Centered(text: emptyText)],
            _ => [
              for (final link in links.requireValue) ...[
                rowBuilder(link),
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          },
          PeopleYouMayKnowRows(
            onOpen: (person) =>
                unawaited(context.push(AppRoutes.person(person.userId))),
          ),
        ],
      ),
    );
  }
}

/// `4177:77`'s card: the person, then Accept and Decline on a row of their own.
///
/// Taller than a Sent row because the two answers are given equal weight — the
/// frame does not bury Decline behind an overflow menu, and neither does this.
class _ReceivedCard extends ConsumerWidget {
  const _ReceivedCard({required this.link});

  final WishLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    Future<void> answer(bool accept) async {
      final actions = ref.read(wishmateActionsProvider);
      final result = accept
          ? await actions.accept(link.linkId)
          : await actions.decline(link.linkId);
      if (context.mounted) reportWishmateResult(context, result);
    }

    return WishmateCard(
      onTap: () =>
          unawaited(context.push(AppRoutes.person(link.person.userId))),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PersonAvatar(person: link.person),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        link.person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        [
                          link.person.handle,
                          ?link.person.mutualLine,
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _Pill(
                    label: 'Accept',
                    filled: true,
                    onPressed: () => unawaited(answer(true)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _Pill(
                    label: 'Decline',
                    filled: false,
                    onPressed: () => unawaited(answer(false)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `4177:111`'s row: the person, and Delete on the right.
class _SentRow extends ConsumerWidget {
  const _SentRow({required this.link});

  final WishLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PersonRow(
      person: link.person,
      onTap: () =>
          unawaited(context.push(AppRoutes.person(link.person.userId))),
      trailing: _Pill(
        label: 'Delete',
        filled: true,
        onPressed: () async {
          final result = await ref
              .read(wishmateActionsProvider)
              .withdraw(link.linkId);
          if (context.mounted) reportWishmateResult(context, result);
        },
      ),
    );
  }
}

/// Accept / Decline / Delete.
///
/// [filled] uses the Color System's CTA plum, sampled at `#3F0E4C` on both
/// `4177:77` and `4177:111`; the outlined form borrows the card's own hairline.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );
    // A fixed height rather than a min-height: the two sit side by side and a
    // one-pixel difference between them reads as a mistake.
    const height = 34.0;

    if (!filled) {
      return SizedBox(
        height: height,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textPrimary,
            side: BorderSide(color: colors.outline),
            shape: shape,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            textStyle: context.text.labelLarge,
          ),
          child: Text(label),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.cta,
          foregroundColor: colors.onCta,
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: context.text.labelLarge,
        ),
        child: Text(label),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.text, this.onRetry});

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
