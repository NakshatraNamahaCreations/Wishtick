import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format/currency.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../domain/gift.dart';
import '../domain/gift_list_item.dart';
import 'gift_list_providers.dart';

/// Gifts Received (`324:1108`), Given (`324:1253`) and On Hold (`324:1210`).
///
/// One screen for all three: the frames are the same card list with the same
/// All / Individual / Group tabs, differing only in the title, whether the
/// counterparty reads "From" or "For", and what the card's footer offers.
/// Three copies of this would drift the moment one card changed.
class GiftListScreen extends ConsumerStatefulWidget {
  const GiftListScreen({required this.kind, super.key});

  final GiftListKind kind;

  @override
  ConsumerState<GiftListScreen> createState() => _GiftListScreenState();
}

class _GiftListScreenState extends ConsumerState<GiftListScreen> {
  GiftListFilter _filter = GiftListFilter.all;

  String get _title => switch (widget.kind) {
    GiftListKind.received => 'Gifts Received',
    GiftListKind.given => 'Gifts Given',
    GiftListKind.onHold => 'Gifts On Hold',
  };

  /// On Hold has no tabs in its frame — it is a short list of your own live
  /// reservations, and splitting it by group would leave two empty tabs.
  bool get _hasTabs => widget.kind != GiftListKind.onHold;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = ref.watch(giftListProvider(widget.kind));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: _title),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Message(
          text: 'Could not load these gifts.',
          onRetry: () => ref.invalidate(giftListProvider(widget.kind)),
        ),
        data: (all) {
          final visible = _hasTabs ? all.where(_filter.matches).toList() : all;

          return Column(
            children: [
              if (_hasTabs)
                _Tabs(
                  selected: _filter,
                  onSelect: (value) => setState(() => _filter = value),
                ),
              Expanded(
                child: visible.isEmpty
                    ? _Message(text: _emptyText, onRetry: null)
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(giftListProvider(widget.kind)),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.lg),
                          itemBuilder: (context, index) => _GiftCard(
                            row: visible[index],
                            kind: widget.kind,
                            onAction: () =>
                                unawaited(_act(context, visible[index])),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Names the active tab when one is filtering, so "You have not given a
  /// gift yet" cannot appear to someone who has given two — just not a group
  /// one, which is what the device showed.
  String get _emptyText {
    if (_hasTabs && _filter != GiftListFilter.all) {
      final what = _filter == GiftListFilter.group ? 'group' : 'individual';
      return widget.kind == GiftListKind.received
          ? 'No $what gifts have arrived yet.'
          : 'You have not given a $what gift yet.';
    }
    return switch (widget.kind) {
      GiftListKind.received => 'No gifts have arrived yet.',
      GiftListKind.given => 'You have not given a gift yet.',
      GiftListKind.onHold => 'Nothing is on hold right now.',
    };
  }

  Future<void> _act(BuildContext context, GiftListItem row) async {
    switch (widget.kind) {
      // "Send Thank You" opens the arrival screen, which knows whether a note
      // exists yet; "Thank You Sent" is inert.
      case GiftListKind.received:
        if (row.thankYouSent || !row.hasArrived) return;
        await context.push<void>(AppRoutes.giftArrival(row.id));
      // "Gift Now" resumes the hand-off the hold was taken for.
      case GiftListKind.onHold:
        await context.push<void>(
          AppRoutes.giftDetails(row.wishlistId, row.itemId),
        );
      // Given cards carry a status pill, not a button.
      case GiftListKind.given:
        break;
    }
  }
}

/// All / Individual / Group, underlined like the frame's tab bar.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect});

  final GiftListFilter selected;
  final ValueChanged<GiftListFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          for (final tab in GiftListFilter.values)
            Expanded(
              child: InkWell(
                onTap: () => onSelect(tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: tab == selected
                            ? colors.primary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    tab.label,
                    textAlign: TextAlign.center,
                    style: context.text.titleSmall?.copyWith(
                      color: tab == selected
                          ? colors.primary
                          : colors.textSecondary,
                      fontWeight: tab == selected
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

/// One card: photo, title, price/counterparty, a delivery or hold line, and
/// whatever action the list offers.
class _GiftCard extends StatelessWidget {
  const _GiftCard({
    required this.row,
    required this.kind,
    required this.onAction,
  });

  final GiftListItem row;
  final GiftListKind kind;
  final VoidCallback onAction;

  /// "From Rohan" on a received gift, "For Rohan" on one you are giving.
  String? get _counterparty {
    if (row.isGroup) return 'Group Gift';
    final name = row.counterpartyName;
    if (name == null) return null;
    return kind == GiftListKind.received ? 'From $name' : 'For $name';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: WishtickImage(url: row.imageUrl),
            ),
          ),
          if (kind == GiftListKind.onHold) ...[
            const SizedBox(height: AppSpacing.md),
            _HoldPill(row: row),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            row.title,
            style: context.text.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              // Received cards lead with the counterparty; the other two lead
              // with the price, exactly as the frames read.
              if (kind != GiftListKind.received && row.amountMinor != null) ...[
                Text(
                  formatInrMinor(row.amountMinor),
                  style: context.text.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              if (_counterparty != null)
                Flexible(child: _CounterpartyChip(label: _counterparty!)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DeliveryLine(row: row, kind: kind),
          if (_actionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _actionEnabled ? onAction : null,
                child: Text(_actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? get _actionLabel => switch (kind) {
    // Nothing to thank anyone for until the gift has actually arrived: the
    // server drafts the note on *fulfil*, so offering it earlier led to a
    // screen whose own button was disabled. A gift still on its way shows its
    // status line and no button.
    GiftListKind.received when !row.hasArrived => null,
    GiftListKind.received =>
      row.thankYouSent ? 'Thank You Sent' : 'Send Thank You',
    // Only a reservation still needs buying. A purchased gift is already
    // bought and waiting to be handed over, so sending its owner back to the
    // merchant would be an invitation to buy it twice.
    GiftListKind.onHold when row.status != GiftStatus.reserved => null,
    GiftListKind.onHold => 'Gift Now',
    GiftListKind.given => null,
  };

  bool get _actionEnabled =>
      !(kind == GiftListKind.received && row.thankYouSent);
}

class _CounterpartyChip extends StatelessWidget {
  const _CounterpartyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.primarySubtle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.card_giftcard,
            size: AppSizes.iconSm,
            color: colors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Delivered on 2 Jul 2026", or a status word when it has not arrived.
class _DeliveryLine extends StatelessWidget {
  const _DeliveryLine({required this.row, required this.kind});

  final GiftListItem row;
  final GiftListKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final delivered = row.deliveredAt;

    final (text, tint) = delivered != null
        ? (
            'Delivered on ${DateFormat('d MMM yyyy').format(delivered.toLocal())}',
            colors.success,
          )
        : switch (row.status) {
            GiftStatus.cancelled => ('Cancelled', colors.textMuted),
            GiftStatus.completed => ('Completed', colors.success),
            GiftStatus.fulfilled => ('On its way', colors.info),
            _ => ('Pending', colors.danger),
          };

    return Row(
      children: [
        Icon(Icons.local_shipping_outlined, size: AppSizes.iconMd, color: tint),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            text,
            style: context.text.bodySmall?.copyWith(color: tint),
          ),
        ),
      ],
    );
  }
}

/// "Held for 1d 3h" — how much of the reservation window is left.
class _HoldPill extends StatelessWidget {
  const _HoldPill({required this.row});

  final GiftListItem row;

  static String _remaining(Duration left) {
    if (left.inDays > 0) return '${left.inDays}d ${left.inHours % 24}h';
    if (left.inHours > 0) return '${left.inHours}h ${left.inMinutes % 60}m';
    return '${left.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final left = row.timeLeft();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.warningSubtle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: AppSizes.iconSm,
            color: colors.onWarningSubtle,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            // A purchased gift has no expiry, so it reads as held outright
            // rather than showing a countdown to nothing.
            left == null
                ? 'On hold'
                : left == Duration.zero
                ? 'Hold expired'
                : 'Held for ${_remaining(left)}',
            style: context.text.bodySmall?.copyWith(
              color: colors.onWarningSubtle,
              fontWeight: FontWeight.w600,
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
