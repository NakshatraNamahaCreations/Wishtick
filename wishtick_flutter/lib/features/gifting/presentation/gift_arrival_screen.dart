import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../notifications/presentation/notification_providers.dart';
import '../domain/gift_list_item.dart';
import 'gift_list_providers.dart';
import 'widgets/celebration_mark.dart';

/// "Your Gift Has Arrived!" (`2012:72`).
///
/// Opened from the gift-fulfilled notification and from a received card. It
/// reads the row out of the received list rather than fetching one gift:
/// there is no `GET /gifts/:id` for a recipient, and by design there cannot be
/// — the list is the only place the anti-spoiler filter has been applied.
class GiftArrivalScreen extends ConsumerWidget {
  const GiftArrivalScreen({required this.giftId, super.key});

  final String giftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final rows = ref.watch(giftListProvider(GiftListKind.received));
    final row = rows.value?.where((g) => g.id == giftId).firstOrNull;
    final note = ref.watch(thankYouForGiftProvider(giftId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context),
      body: rows.isLoading
          ? const Center(child: CircularProgressIndicator())
          : row == null
          ? _Missing(onBack: () => context.pop())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              children: [
                // The frame's magenta gift-box illustration is not in
                // `UI_Screen/`, so the burst wraps the brand mark — the same
                // substitution the order-confirmed screen already makes.
                const Center(
                  child: CelebrationMark(
                    size: 140,
                    child: Image(
                      image: AssetImage('assets/logo/logo.png'),
                      width: 120,
                      height: 120,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Your Gift Has Arrived!',
                  textAlign: TextAlign.center,
                  style: AppTypography.displaySmall.copyWith(
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'We hope it makes your day even brighter.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyLarge?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                _DetailCard(row: row),
                if (row.deliveredAt != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    DateFormat(
                      'd MMM, h:mm a',
                    ).format(row.deliveredAt!.toLocal()),
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxxl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // Disabled while the notes are still loading rather than
                    // guessing: tapping through to a note that turns out to be
                    // sent would be a dead end.
                    onPressed: row.thankYouSent
                        ? null
                        : note == null
                        ? null
                        : () => unawaited(
                            context.push<void>(AppRoutes.thankYou(note.id)),
                          ),
                    child: Text(
                      row.thankYouSent ? 'Thank You Sent' : 'Send Thank You',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => unawaited(
                      context.push<void>(
                        AppRoutes.giftItem(row.wishlistId, row.itemId),
                      ),
                    ),
                    child: const Text('View Gift Details'),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Gift / From / Event, each a small caption over its value.
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.row});

  final GiftListItem row;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Field(label: 'Gift', value: row.title),
          if (row.counterpartyName != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _Field(
              label: 'From',
              value: row.isGroup
                  ? '${row.counterpartyName} and others'
                  : row.counterpartyName!,
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: context.text.titleSmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'This gift is no longer in your list.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(onPressed: onBack, child: const Text('Go back')),
      ],
    ),
  );
}
