import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import 'event_providers.dart';

/// "My Events & Invites" (`324:973`).
///
/// Two tabs — the events you host and the ones you were invited to — each
/// filtered All / Upcoming / Past. This is the only entry point to a host's
/// guest list, which Sprint 7 built with nothing linking to it.
class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

/// The three pills under the tab bar.
enum _When {
  all('All'),
  upcoming('Upcoming'),
  past('Past');

  const _When(this.label);

  final String label;

  bool matches(DateTime startsAt, DateTime now) => switch (this) {
    all => true,
    upcoming => !startsAt.isBefore(now),
    past => startsAt.isBefore(now),
  };
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen> {
  bool _hosting = true;
  _When _when = _When.all;

  /// The events ticked for deletion. Empty means the screen is in its normal
  /// state — there is no separate "selection mode" flag to fall out of sync.
  final _selected = <String>{};

  bool _deleting = false;

  bool get _selecting => _selected.isNotEmpty;

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  void _clearSelection() => setState(_selected.clear);

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          count == 1 ? 'Delete this event?' : 'Delete $count events?',
        ),
        content: Text(
          count == 1
              ? 'It will be removed for good. Anyone holding an invitation '
                    'link for it will find nothing there.'
              : 'They will be removed for good. Anyone holding an invitation '
                    'link for them will find nothing there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final deleted = await ref
          .read(eventsRepositoryProvider)
          .deleteMany(_selected.toList());
      if (!mounted) return;
      _clearSelection();
      ref.invalidate(myEventsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted == 1 ? 'Event deleted.' : '$deleted events deleted.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _selecting
          ? _SelectionAppBar(
              count: _selected.length,
              busy: _deleting,
              onCancel: _clearSelection,
              onDelete: () => unawaited(_deleteSelected()),
            )
          : circleBackAppBar(context, title: 'My Events & Invites'),
      body: Column(
        children: [
          _Tabs(
            hosting: _hosting,
            onSelect: (value) => setState(() {
              _hosting = value;
              // Selection belongs to the hosted grid; carrying it across would
              // leave a delete armed against rows that are no longer on screen.
              _selected.clear();
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          _WhenPills(
            selected: _when,
            onSelect: (value) => setState(() => _when = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _hosting
                ? _HostedGrid(
                    when: _when,
                    now: now,
                    selected: _selected,
                    onToggle: _toggle,
                  )
                : _InvitedGrid(when: _when, now: now),
          ),
        ],
      ),
    );
  }
}

class _HostedGrid extends ConsumerWidget {
  const _HostedGrid({
    required this.when,
    required this.now,
    required this.selected,
    required this.onToggle,
  });

  final _When when;
  final DateTime now;

  /// Ids ticked for deletion. Non-empty puts the grid in selection mode.
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(myEventsProvider);

    return events.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _Message(
        text: 'Could not load your events.',
        onRetry: () => ref.invalidate(myEventsProvider),
      ),
      data: (all) {
        final visible = all
            .where((e) => when.matches(e.startsAt, now))
            .toList();
        if (visible.isEmpty) {
          return const _Message(text: 'No events here yet.', onRetry: null);
        }
        return _Grid(
          children: [
            for (final event in visible)
              _EventCard(
                title: event.title,
                startsAt: event.startsAt,
                imageUrl: event.inviteMediaUrl ?? event.coverUrl,
                selected: selected.contains(event.id),
                // Once anything is ticked, a tap picks rather than opens.
                // Leaving tap as "open" mid-selection is how people lose a
                // selection they were half way through building.
                // Opens the event, not the guest list. The grid used to jump
                // straight to the guests, so a host could not look at their own
                // party at all — not the artwork, the date or the description.
                onTap: selected.isEmpty
                    ? () => unawaited(
                        context.push<void>(AppRoutes.eventDetail(event.id)),
                      )
                    : () => onToggle(event.id),
                // Long press is what starts it, the way every list that has
                // ever had multi-select behaves.
                onLongPress: () => onToggle(event.id),
                footnote: _rsvpLine(event),
                badgeCount: event.pendingWishlistCount,
              ),
          ],
        );
      },
    );
  }

  /// "12 going · 3 pending", when the host's counts came down.
  static String? _rsvpLine(WishtickEventDetail event) {
    final counts = event.rsvpCounts;
    if (counts == null) return null;
    return '${counts.yes} going · ${counts.pending} pending';
  }
}

class _InvitedGrid extends ConsumerWidget {
  const _InvitedGrid({required this.when, required this.now});

  final _When when;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(invitedEventsProvider);

    return events.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _Message(
        text: 'Could not load your invites.',
        onRetry: () => ref.invalidate(invitedEventsProvider),
      ),
      data: (all) {
        final visible = all
            .where((e) => when.matches(e.startsAt, now))
            .toList();
        if (visible.isEmpty) {
          return const _Message(
            text: 'No invitations here yet.',
            onRetry: null,
          );
        }
        return _Grid(
          children: [
            for (final event in visible)
              _EventCard(
                title: event.title,
                startsAt: event.startsAt,
                // The invitation first, as on the host's own card above: an
                // event made in the app has one and no cover.
                imageUrl: event.artworkUrl,
                footnote: event.hasAnswered
                    ? 'You said ${event.myRsvp.label.toLowerCase()}'
                    : 'RSVP pending',
                // A guest's card opens their own invitation, which is where
                // the RSVP lives. Without a token there is nothing to open.
                onTap: event.inviteToken == null
                    ? null
                    : () => unawaited(
                        context.push<void>(
                          AppRoutes.invite(event.inviteToken!),
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }
}

/// My Events / Invites, underlined like the frame.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.hosting, required this.onSelect});

  final bool hosting;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          for (final tab in [(true, 'My Events'), (false, 'Invites')])
            Expanded(
              child: InkWell(
                onTap: () => onSelect(tab.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: tab.$1 == hosting
                            ? colors.primary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    tab.$2,
                    textAlign: TextAlign.center,
                    style: context.text.titleSmall?.copyWith(
                      color: tab.$1 == hosting
                          ? colors.primary
                          : colors.textSecondary,
                      fontWeight: tab.$1 == hosting
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WhenPills extends StatelessWidget {
  const _WhenPills({required this.selected, required this.onSelect});

  final _When selected;
  final ValueChanged<_When> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (final pill in _When.values) ...[
            Expanded(
              child: Material(
                color: pill == selected ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  onTap: () => onSelect(pill),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    height: AppSizes.chipHeight + AppSpacing.sm,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: pill == selected
                          ? null
                          : Border.all(color: colors.primaryMuted),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      pill.label,
                      style: context.text.bodyMedium?.copyWith(
                        color: pill == selected
                            ? colors.onPrimary
                            : colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (pill != _When.values.last) const SizedBox(width: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

/// Two portrait invitation cards per row, as the frame lays them out.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.xxl,
    ),
    crossAxisCount: 2,
    crossAxisSpacing: AppSpacing.lg,
    mainAxisSpacing: AppSpacing.lg,
    childAspectRatio: 0.62,
    children: children,
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.title,
    required this.startsAt,
    required this.imageUrl,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.footnote,
    this.badgeCount = 0,
  });

  final String title;
  final DateTime startsAt;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final String? footnote;

  /// Guest wishlists waiting on an answer. Zero draws nothing.
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: WishtickImage(url: imageUrl),
                  ),
                ),
                if (selected)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: colors.primary, width: 3),
                      // Dimmed as well as outlined: a border alone is easy to
                      // miss on artwork that already has a strong edge.
                      color: colors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: _SelectionTick(selected: selected),
                ),
                // Hidden while picking cards to delete: the tick takes that
                // corner, and a count is not what the host is reading then.
                if (badgeCount > 0 && !selected)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _PendingBadge(count: badgeCount),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            DateFormat('d MMM yyyy').format(startsAt.toLocal()),
            style: context.text.bodySmall?.copyWith(color: colors.textMuted),
          ),
          if (footnote != null)
            Text(
              footnote!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// "2 waiting" on an event whose host has guest wishlists to answer.
///
/// The queue is at the foot of the event's page, and nothing used to say it
/// was there — so an offer sat unanswered and the guest was never told why.
class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label:
          '$count guest ${count == 1 ? 'wishlist' : 'wishlists'} waiting '
          'for your answer',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          '$count waiting',
          style: context.text.labelSmall?.copyWith(
            color: colors.onAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.md),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ],
    ),
  );
}

/// The tick in a card's corner while a selection is being built.
///
/// Always drawn once selection starts, filled or hollow, so the affordance is
/// visible on every card rather than only on the ones already chosen.
class _SelectionTick extends StatelessWidget {
  const _SelectionTick({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (!selected) return const SizedBox.shrink();

    return Container(
      width: AppSizes.iconLg,
      height: AppSizes.iconLg,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primary,
        border: Border.all(color: colors.onPrimary, width: 2),
      ),
      child: Icon(Icons.check, size: AppSizes.iconSm, color: colors.onPrimary),
    );
  }
}

/// Replaces the title bar while a selection is being built.
///
/// A separate bar rather than a floating button: it takes over the one place
/// on screen that is always visible, says how many are picked, and gives an
/// unambiguous way out — which a bottom sheet over a scrolling grid does not.
class _SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SelectionAppBar({
    required this.count,
    required this.busy,
    required this.onCancel,
    required this.onDelete,
  });

  final int count;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppBar(
      backgroundColor: colors.background,
      leading: IconButton(
        onPressed: busy ? null : onCancel,
        icon: const Icon(Icons.close),
        tooltip: 'Cancel selection',
      ),
      title: Text(
        '$count selected',
        style: context.text.titleMedium?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SizedBox(
              width: AppSizes.iconMd,
              height: AppSizes.iconMd,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          )
        else
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: colors.danger),
            tooltip: 'Delete selected',
          ),
      ],
    );
  }
}
