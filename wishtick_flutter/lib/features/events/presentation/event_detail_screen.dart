import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../../auth/presentation/session_controller.dart';
import '../../wishlist/presentation/widgets/wishlist_picker_sheet.dart';
import '../../wishmates/presentation/widgets/quick_share_sheet.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import 'event_providers.dart';
import 'invite_contacts_screen.dart';
import 'widgets/event_wishlist_requests.dart';

/// The host's own event, opened from "My Events".
///
/// The same shape as [InviteScreen], which is the *guest's* view of the same
/// party — but this one is reached by id with a bearer rather than by an invite
/// token, and it shows what only the host may see: the guest list, and the
/// event while it is still a draft.
///
/// It replaced a tap that went straight to the guest list. That was the only
/// thing linked from the grid, so a host could not look at their own event at
/// all — not the artwork they made, not the date, not the description.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final event = ref.watch(eventDetailProvider(eventId));
    // Inviting people is the thing a host comes back to this page to do, so it
    // sits in the bar rather than as two rows down in Quick Suggestions.
    // Nothing to invite to until the event has loaded.
    final loaded = event.value;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(
        context,
        actions: loaded == null ? null : [_InviteAction(event: loaded)],
      ),
      // Error before loading: Riverpod retries a failed provider, so a failed
      // one is *also* loading — matching `hasValue: false` first would spin
      // forever on a request that has already given up.
      body: switch (event) {
        AsyncValue(hasError: true, hasValue: false) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const WishtickErrorText('Could not load this event.'),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => ref.invalidate(eventDetailProvider(eventId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        AsyncValue(hasValue: false) => const Center(
          child: CircularProgressIndicator(),
        ),
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(eventDetailProvider(eventId));
            await ref.read(eventDetailProvider(eventId).future);
          },
          child: _Body(event: value),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.event});

  final WishtickEventDetail event;

  /// Attaches one of the host's own wishlists to this event.
  ///
  /// The row is drawn whether or not a list is attached: hiding it left the
  /// screen with no way to add one, and no hint that an event *can* carry a
  /// list at all.
  Future<void> _attachWishlist(BuildContext context, WidgetRef ref) async {
    final picked = await showWishlistPickerSheet(context);
    if (picked == null || !context.mounted) return;

    try {
      await ref
          .read(eventsRepositoryProvider)
          .update(event.id, wishlistIds: [...event.wishlistIds, picked.id]);
      ref.invalidate(eventDetailProvider(event.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${picked.title} attached to this event.')),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    // The host is whoever is signed in — this screen is only ever reached from
    // their own "My Events", and an EventView carries no host name to read.
    final host = ref.watch(sessionProvider).user?.name?.trim();
    final startsAt = event.startsAt.toLocal();
    final daysAway = DateUtils.dateOnly(
      startsAt,
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    // The invitation the host made, falling back to the event's cover. Either
    // may be absent — a draft often has neither — and the card is simply not
    // drawn rather than replaced by an empty box.
    final invitation = event.inviteMediaUrl;
    final artwork =
        invitation != null && MediaRepository.isDrawableImage(invitation)
        ? invitation
        : event.coverUrl;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        Center(
          child: Column(
            children: [
              Text(
                event.title,
                textAlign: TextAlign.center,
                style: context.text.headlineMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _whenLine(startsAt, daysAway),
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (event.personName != null)
                Text(
                  'For ${event.personName}',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _StatusChip(status: event.status),
        const SizedBox(height: AppSpacing.lg),
        if (artwork != null)
          // Whole, at its own proportions. The card is the host's work and is
          // read as a whole; a fixed 3:4 box cropped the last line off every
          // design that was any other shape.
          SizedBox(
            width: double.infinity,
            child: WishtickImage(
              url: artwork,
              fit: BoxFit.fitWidth,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        if (event.description != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'About Event',
            style: context.text.headlineSmall?.copyWith(
              // See headlineBrandColor: plum measures 1.61:1 on the dark page,
              // so a headline drawn in it is unreadable there.
              color: context.headlineBrandColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            event.description!,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
        if (host != null && host.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Hosted By',
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          Text(
            host,
            style: context.text.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        // Unlike the invitee's view, an Event does carry a venue — so the
        // location line here is real rather than omitted.
        if (event.venue != null)
          _IconLine(icon: Icons.place_outlined, text: event.venue!),
        _IconLine(
          icon: Icons.schedule,
          text: DateFormat('EEE, d MMM • h:mm a').format(startsAt),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Quick Suggestions',
          style: context.text.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // The design's order: what the party needs, then who is coming.
        _SuggestionRow(
          icon: Icons.favorite_border,
          title: 'View Wishlist',
          subtitle: switch (event.wishlistIds.length) {
            0 => 'Attach one so guests know what to bring',
            1 => '1 list attached',
            final n => '$n lists attached',
          },
          onTap: event.wishlistIds.isEmpty
              ? () => unawaited(_attachWishlist(context, ref))
              : () => unawaited(
                  context.push<void>(
                    AppRoutes.wishlistDetail(event.wishlistIds.first),
                  ),
                ),
        ),
        _SuggestionRow(
          icon: Icons.people_alt_outlined,
          title: 'Guest List',
          subtitle: _guestLine(event),
          onTap: () =>
              unawaited(context.push<void>(AppRoutes.eventGuests(event.id))),
        ),
        // Inviting people moved to the bar's invite action, which is where a
        // host reaches for it — it is the errand they open this page to run,
        // not a suggestion. Group Gifts and Add Your Wish, the design's other
        // two rows, stay absent rather than drawn dead:
        //
        //  * a GroupGift hangs off a wishlist *item*, not an event, so "the
        //    group gifts for this party" is a query no endpoint answers — it
        //    would mean walking event → wishlists → items → gifts;
        //  * "Add Your Wish" is a guest's action. On the host's own event it
        //    would open the very list "View Wishlist" already opens.
        //
        // Guests offering their own lists is different: the host has to answer
        // it, and this is the only place they can.
        EventWishlistRequestsSection(eventId: event.id),
      ],
    );
  }

  /// "26 Jul • 2 Days Left", the way the design writes it.
  static String _whenLine(DateTime startsAt, int daysAway) => [
    DateFormat('d MMM').format(startsAt),
    if (daysAway > 1)
      '$daysAway Days Left'
    else if (daysAway == 1)
      'Tomorrow'
    else if (daysAway == 0)
      'Today'
    else
      'Past',
  ].join(' • ');

  /// "10 going · 3 pending", or an invitation to start inviting.
  static String _guestLine(WishtickEventDetail event) {
    final counts = event.rsvpCounts;
    if (counts == null || counts.invited == 0) return 'Nobody invited yet';
    return '${counts.yes} going · ${counts.pending} pending';
  }
}

/// The bar's invite action: the two ways a host gets people to their party.
///
/// It used to be two rows in Quick Suggestions. Inviting is the errand a host
/// opens this page to run, not a suggestion, so it sits in the bar — and the
/// list below is back to what the design has on it.
class _InviteAction extends ConsumerWidget {
  const _InviteAction({required this.event});

  final WishtickEventDetail event;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    onPressed: () => unawaited(_showInviteSheet(context, ref, event)),
    icon: const Icon(Icons.person_add_alt_1_outlined),
    tooltip: 'Invite people',
    color: context.colors.textPrimary,
  );
}

/// "Invite WishMates" and "Share Invitation Link", as a sheet.
///
/// Shown even for a draft, with both ways greyed and the reason on them: an
/// action that vanishes teaches a host nothing about when it comes back.
Future<void> _showInviteSheet(
  BuildContext context,
  WidgetRef ref,
  WishtickEventDetail event,
) async {
  // Only a published event can be invited to: the server refuses invites for
  // a draft, and a cancelled or finished party has nobody left to invite.
  final canInvite = event.status.acceptsInvites;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final colors = sheetContext.colors;
      return Material(
        color: colors.background,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Invite people',
                  style: sheetContext.text.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SuggestionRow(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Invite WishMates',
                  subtitle: canInvite
                      ? 'Pick who to send the invitation to'
                      : 'Only a published event can be shared',
                  // The sheet closes first: the WishMates picker is itself a
                  // sheet, and two stacked on one another is a dead end.
                  onTap: canInvite
                      ? () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_inviteWishmates(context, ref, event));
                        }
                      : null,
                ),
                _SuggestionRow(
                  icon: Icons.contacts_outlined,
                  title: 'Invite from Contacts',
                  subtitle: canInvite
                      ? 'For friends who are not on Wishtick yet'
                      : 'Only a published event can be shared',
                  onTap: canInvite
                      ? () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_inviteFromContacts(context, ref, event));
                        }
                      : null,
                ),
                _SuggestionRow(
                  icon: Icons.link,
                  title: 'Share Invitation Link',
                  subtitle: canInvite
                      ? 'WhatsApp, Instagram, or copy the link'
                      : 'Only a published event can be shared',
                  onTap: canInvite
                      ? () {
                          Navigator.of(sheetContext).pop();
                          unawaited(
                            context.push<void>(AppRoutes.eventShare(event.id)),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Picking guests out of the host's address book.
///
/// The explanation comes first and the OS prompt only after "OK": a permission
/// sheet that appears out of nowhere is the one people refuse, and refusing it
/// on Android is often permanent.
Future<void> _inviteFromContacts(
  BuildContext context,
  WidgetRef ref,
  WishtickEventDetail event,
) async {
  if (!await confirmContactsPermission(context)) return;
  if (!context.mounted) return;

  final invited = await Navigator.of(context).push<int>(
    MaterialPageRoute(builder: (_) => InviteContactsScreen(event: event)),
  );
  if (invited == null || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        invited == 1
            ? 'Invited 1 person. They can open the invitation once they sign '
                  'in with that number.'
            : 'Invited $invited people. They can open the invitation once '
                  'they sign in with those numbers.',
      ),
    ),
  );
}

/// The grid of WishMates, one send. What the guest list is made of.
Future<void> _inviteWishmates(
  BuildContext context,
  WidgetRef ref,
  WishtickEventDetail event,
) async {
  await showQuickShareSheet(
    context,
    EventShareTarget(
      eventId: event.id,
      title: event.title,
      slug: event.share?.slug,
      // Whether the link admits anyone: it does for public *and* invite-only
      // events; only a private event's link is refused by the server.
      isPublic: event.visibility != EventVisibility.private,
    ),
  );
  // The guest line on this page counts what was just sent.
  ref.invalidate(eventDetailProvider(event.id));
}

/// Draft / published / cancelled, which only the host can see.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, background, foreground) = switch (status) {
      EventStatus.draft => (
        'Draft — not sent yet',
        colors.warningSubtle,
        colors.onWarningSubtle,
      ),
      EventStatus.published => (
        'Published',
        colors.successSubtle,
        colors.onSuccessSubtle,
      ),
      EventStatus.cancelled => (
        'Cancelled',
        colors.dangerSubtle,
        colors.danger,
      ),
      EventStatus.completed => (
        'Finished',
        colors.primarySubtle,
        colors.primary,
      ),
    };

    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: context.text.bodySmall?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconMd, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium?.copyWith(color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Null draws the row dead — greyed, with the subtitle saying why — rather
  /// than hiding it, so the host can see what the page will offer.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: AppSizes.avatarSm + 8,
                  height: AppSizes.avatarSm + 8,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primarySubtle,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    icon,
                    size: AppSizes.iconMd,
                    color: enabled ? colors.primary : colors.textMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.text.titleSmall?.copyWith(
                          color: enabled
                              ? colors.textPrimary
                              : colors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: context.text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: AppSizes.iconMd,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
