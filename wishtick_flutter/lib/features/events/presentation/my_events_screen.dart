import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_image.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'My Events & Invites'),
      body: Column(
        children: [
          _Tabs(
            hosting: _hosting,
            onSelect: (value) => setState(() => _hosting = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          _WhenPills(
            selected: _when,
            onSelect: (value) => setState(() => _when = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _hosting
                ? _HostedGrid(when: _when, now: now)
                : _InvitedGrid(when: _when, now: now),
          ),
        ],
      ),
    );
  }
}

class _HostedGrid extends ConsumerWidget {
  const _HostedGrid({required this.when, required this.now});

  final _When when;
  final DateTime now;

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
                // The host's own event opens its guest list — the screen
                // Sprint 7 built and nothing linked to.
                onTap: () => unawaited(
                  context.push<void>(AppRoutes.eventGuests(event.id)),
                ),
                footnote: _rsvpLine(event),
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
                imageUrl: event.coverUrl,
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
    this.footnote,
  });

  final String title;
  final DateTime startsAt;
  final String? imageUrl;
  final VoidCallback? onTap;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: double.infinity,
                child: WishtickImage(url: imageUrl),
              ),
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
