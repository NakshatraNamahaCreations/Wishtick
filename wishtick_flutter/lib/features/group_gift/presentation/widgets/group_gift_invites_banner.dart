import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../group_gift_invites_screen.dart';

/// "You have been asked to chip in" — the way into an unanswered invitation.
///
/// The notification used to be the only route to the invites screen, so an
/// invitation whose notification was cleared, missed, or never pushed could not
/// be reached at all: it sat pending while the host saw "already invited" and
/// the invitee saw nothing. A pending invitation is a question waiting on an
/// answer, and it belongs somewhere that survives a swiped notification.
///
/// Draws nothing at all when there is nothing pending — including while
/// loading or after a failure. A banner that flashes a spinner or an error
/// across the top of Home costs more than the invitation is worth; the next
/// refresh picks it up.
class GroupGiftInvitesBanner extends ConsumerWidget {
  const GroupGiftInvitesBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(groupGiftInvitesProvider).value ?? const [];
    if (invites.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final one = invites.length == 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              unawaited(context.push<void>(AppRoutes.groupGiftInvites)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.card_giftcard_outlined,
                    color: colors.primary,
                    size: AppSizes.iconMd,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        one
                            // Names the group when there is exactly one, so the
                            // tap is not a leap of faith.
                            ? 'Chip in for ${invites.single.groupTitle}?'
                            : '${invites.length} group gift invitations',
                        style: context.text.bodyLarge?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        one
                            ? 'Tap to accept or decline.'
                            : 'Tap to accept or decline them.',
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
      ),
    );
  }
}
