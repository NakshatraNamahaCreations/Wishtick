import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';
import 'notification_destination.dart';
import 'notification_providers.dart';

/// "Notification Center" (`324:1392`).
///
/// Filter chips across the top, then rows grouped into Today / Yesterday /
/// Earlier. An unread row carries a dot on its left edge.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  /// Null is the "All" chip.
  NotificationCategory? _filter;

  /// The chips the frame shows, in its order. Account notifications have no
  /// chip of their own; they land under All, which is where someone looks for
  /// "your password changed" — not under a category tab.
  static const _chips = <NotificationCategory?>[
    null,
    NotificationCategory.events,
    NotificationCategory.gifts,
    NotificationCategory.groupGifts,
    NotificationCategory.memories,
  ];

  Future<void> _open(AppNotification row) async {
    if (!row.read) {
      // Fire and forget, then repaint from the local edit: waiting on the
      // round trip would leave the dot up while the next screen opens.
      unawaited(
        ref.read(notificationsRepositoryProvider).markRead(row.id).then((_) {
          ref.invalidate(notificationsProvider);
        }),
      );
    }
    // Shared with the push-tap handler, so a notification lands in the same
    // place whether it was opened from here or from the lock screen.
    final destination = destinationFor(row.type, row.refId);
    if (destination == null || !mounted) return;
    await context.push<void>(destination);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'Notification Center'),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Empty(
          text: 'Could not load your notifications.',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (all) {
          final visible = _filter == null
              ? all
              : all.where((n) => n.category == _filter).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                _Chips(
                  chips: _chips,
                  selected: _filter,
                  onSelect: (value) => setState(() => _filter = value),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (visible.isEmpty)
                  _Empty(
                    text: _filter == null
                        ? 'Nothing here yet.'
                        : 'Nothing under ${_filter!.label} yet.',
                    onRetry: null,
                  )
                else
                  for (final group in _groupByDay(visible)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: Text(
                        group.label,
                        style: context.text.titleMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    for (final row in group.rows)
                      _NotificationTile(
                        row: row,
                        onTap: () => unawaited(_open(row)),
                      ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Rows already arrive newest-first, so one pass is enough to split them.
({String label, List<AppNotification> rows}) _band(
  String label,
  List<AppNotification> rows,
) => (label: label, rows: rows);

List<({String label, List<AppNotification> rows})> _groupByDay(
  List<AppNotification> rows,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final todayRows = <AppNotification>[];
  final yesterdayRows = <AppNotification>[];
  final earlier = <AppNotification>[];

  for (final row in rows) {
    final at = row.createdAt.toLocal();
    final day = DateTime(at.year, at.month, at.day);
    if (day == today) {
      todayRows.add(row);
    } else if (day == yesterday) {
      yesterdayRows.add(row);
    } else {
      earlier.add(row);
    }
  }

  return [
    if (todayRows.isNotEmpty) _band('Today', todayRows),
    if (yesterdayRows.isNotEmpty) _band('Yesterday', yesterdayRows),
    if (earlier.isNotEmpty) _band('Earlier', earlier),
  ];
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.chips,
    required this.selected,
    required this.onSelect,
  });

  final List<NotificationCategory?> chips;
  final NotificationCategory? selected;
  final ValueChanged<NotificationCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final chip in chips)
            _Chip(
              label: chip?.label ?? 'All',
              selected: chip == selected,
              onTap: () => onSelect(chip),
              colors: colors,
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final WishtickColors colors;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? colors.primary : colors.chipFill,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Text(
          label,
          style: context.text.bodyMedium?.copyWith(
            color: selected ? colors.onPrimary : colors.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

/// One row: unread dot, category tile, title, subtitle, time.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.row, required this.onTap});

  final AppNotification row;
  final VoidCallback onTap;

  /// The subtitle is whichever bit of context the payload carries. Read off
  /// the payload rather than the body, because the body is already the title.
  String? get _subtitle {
    for (final key in ['itemTitle', 'eventTitle', 'memoryTitle', 'title']) {
      final value = row.payload[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return row.body.isEmpty ? null : row.body;
  }

  (IconData, Color) _glyph(WishtickColors colors) => switch (row.category) {
    NotificationCategory.events => (Icons.cake_outlined, colors.celebration),
    NotificationCategory.gifts => (Icons.card_giftcard, colors.primary),
    NotificationCategory.groupGifts => (Icons.groups_outlined, colors.success),
    NotificationCategory.memories => (Icons.auto_awesome, colors.celebration),
    NotificationCategory.reels => (Icons.movie_outlined, colors.info),
    NotificationCategory.social => (Icons.chat_bubble_outline, colors.info),
    NotificationCategory.account => (Icons.shield_outlined, colors.textMuted),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, tint) = _glyph(colors);
    final subtitle = _subtitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.lg,
            child: row.read
                ? null
                : Icon(Icons.circle, size: 6, color: colors.primary),
          ),
          Expanded(
            child: Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: tint,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          icon,
                          color: colors.textOnDark,
                          size: AppSizes.iconLg,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.title,
                              style: context.text.titleSmall?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodySmall?.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                DateFormat(
                                  'h:mm a',
                                ).format(row.createdAt.toLocal()),
                                style: context.text.bodySmall?.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _Empty extends StatelessWidget {
  const _Empty({required this.text, required this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
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
          const SizedBox(height: AppSpacing.md),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ],
    ),
  );
}
