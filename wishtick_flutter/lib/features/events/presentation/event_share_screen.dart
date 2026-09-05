import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/share_via_grid.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../../wishlist/data/wishlist_repository.dart';
import '../../wishlist/domain/wishlist.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import 'event_providers.dart';

/// The wishlists linked to an event, in full. The row needs their item
/// counts, and the event carries only their ids.
final _linkedWishlistsProvider = FutureProvider.autoDispose
    .family<List<Wishlist>, String>((ref, eventId) async {
      final event = await ref.watch(eventDetailProvider(eventId).future);
      final repo = ref.watch(wishlistRepositoryProvider);
      return Future.wait(event.wishlistIds.map(repo.getOne));
    });

/// "Share Your Invite" — where both invitation flows end.
///
/// The first screen on which the event exists: the preview's button created
/// and published it on the way here. What goes out is the event's own link,
/// which admits anyone who signs in; WishMates are invited by name from the
/// guest list instead.
class EventShareScreen extends ConsumerWidget {
  const EventShareScreen({required this.eventId, super.key});

  final String eventId;

  /// "19 Jul 2026 · 8:00 PM", as the design writes it.
  static final _dateLine = DateFormat('d MMM yyyy · h:mm a');

  String _message(WishtickEventDetail e) {
    final venue = e.venue?.trim();
    final where = venue == null || venue.isEmpty ? '' : ' at $venue';
    return "You're invited to ${e.title} on ${_dateLine.format(e.startsAt.toLocal())}"
        '$where. See the invitation on Wishtick';
  }

  Future<void> _attachWishlist(
    BuildContext context,
    WidgetRef ref,
    WishtickEventDetail event,
  ) async {
    final wishlist = await context.push<Wishlist>(AppRoutes.wishlistCreate);
    if (wishlist == null) return;
    await ref
        .read(eventsRepositoryProvider)
        .update(event.id, wishlistIds: [...event.wishlistIds, wishlist.id]);
    ref.invalidate(eventDetailProvider(event.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final event = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context),
      body: event.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: WishtickErrorText('Could not load this event.'),
        ),
        data: (e) {
          final share = e.share?.url;
          // A private event's link is refused by the server for everybody, so
          // handing it out would send guests to a 404 with no explanation on
          // either side. Events the app creates are invite-only; this is for
          // the ones made before that, or made private on purpose.
          final linkAdmits = e.visibility != EventVisibility.private;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Your Invite',
                      style: context.text.displaySmall?.copyWith(
                        color: context.headlineBrandColor,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Invite WishMates & Family',
                      style: context.text.bodyLarge?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _EventCard(
                event: e,
                dateLine: _dateLine.format(e.startsAt.toLocal()),
              ),
              const SizedBox(height: AppSpacing.lg),
              _LinkedWishlistRow(
                wishlists: ref.watch(_linkedWishlistsProvider(eventId)),
                onTap: (first) => first == null
                    ? unawaited(_attachWishlist(context, ref, e))
                    : unawaited(
                        context.push<void>(AppRoutes.wishlistDetail(first.id)),
                      ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!linkAdmits)
                const _LinkWontWorkNotice()
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(
                    'Share Your Invite Via',
                    style: context.text.titleMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Dead, not hidden, without a link: only the host gets one,
                // and a guest who lands here should see what the screen is
                // for.
                ShareViaGrid(
                  enabled: share != null,
                  onTap: (target) => unawaited(
                    shareTo(
                      context,
                      target,
                      url: share!,
                      message: _message(e),
                      subject: e.title,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Shown instead of the share grid when the event is private: the server
/// answers its link with a 404 for everyone, so the only way in is by name.
class _LinkWontWorkNotice extends StatelessWidget {
  const _LinkWontWorkNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.warningSubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: AppSizes.iconMd,
                color: colors.onWarningSubtle,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'A link won’t open this event',
                  style: context.text.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This event is Private, so only the people you invite by name '
            'can open it. Invite your WishMates from the event page instead.',
            style: context.text.bodyMedium?.copyWith(
              color: colors.textPrimary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

/// The invitation beside what it is for.
class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.dateLine});

  final WishtickEventDetail event;
  final String dateLine;

  /// The card, or the cover when the invitation is a file that cannot be
  /// drawn (an MP4, a PDF).
  String? get _thumbnail {
    final invite = event.inviteMediaUrl;
    if (invite != null && MediaRepository.isDrawableImage(invite)) {
      return invite;
    }
    return event.coverUrl;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final venue = event.venue?.trim();

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              height: 140,
              child: WishtickImage(
                url: _thumbnail,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    dateLine,
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  if (venue != null && venue.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      venue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Linked Wishlist — 8 items ready to gift". Opens the list, or makes one
/// when there is none yet.
class _LinkedWishlistRow extends StatelessWidget {
  const _LinkedWishlistRow({required this.wishlists, required this.onTap});

  final AsyncValue<List<Wishlist>> wishlists;

  /// Handed the first linked list, or null when there is none to open.
  final ValueChanged<Wishlist?> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final linked = wishlists.value ?? const <Wishlist>[];
    final items = linked.fold<int>(0, (sum, w) => sum + w.itemCount);
    final subtitle = wishlists.when(
      loading: () => 'Loading…',
      error: (_, _) => 'Could not load the wishlist',
      data: (lists) => lists.isEmpty
          ? 'No wishlist linked yet — tap to create one'
          : '$items ${items == 1 ? 'item' : 'items'} ready to gift',
    );

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: wishlists.isLoading ? null : () => onTap(linked.firstOrNull),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: AppSizes.avatarMd,
                height: AppSizes.avatarMd,
                decoration: BoxDecoration(
                  color: colors.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.card_giftcard,
                  color: colors.primary,
                  size: AppSizes.iconMd,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linked Wishlist',
                      style: context.text.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right,
                color: colors.textMuted,
                size: AppSizes.iconMd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
