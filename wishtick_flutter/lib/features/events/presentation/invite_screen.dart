import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../domain/event_wishlist_request.dart';
import '../domain/public_invite.dart';
import 'invite_controller.dart';
import 'widgets/event_wishlist_requests.dart';

/// Figma `291:1008` — an invite, opened by its token.
///
/// Public: the token is the authorization, so this renders without a session.
/// A signed-in guest still sends their bearer, which is what links the invite
/// to their account and makes an event-only wishlist resolve afterwards.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(inviteProvider(widget.token).notifier).ensureLoaded(),
    );
  }

  Future<void> _respond(RsvpResponse response) async {
    final ok = await ref
        .read(inviteProvider(widget.token).notifier)
        .respond(response);
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(inviteProvider(widget.token)).error;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('RSVP saved — ${response.label}.')));
  }

  /// This guest's own offer to this event, newest first, or null.
  ///
  /// Read from the caller's whole list rather than a per-event endpoint —
  /// there is no such endpoint, and a guest has a handful of offers at most.
  EventWishlistRequest? _myOfferFor(String eventId) {
    final mine = ref.watch(myEventWishlistRequestsProvider).value;
    if (mine == null) return null;
    final forThis = mine.where((r) => r.eventId == eventId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return forThis.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inviteProvider(widget.token));
    final invite = state.invite;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: switch ((invite, state.error)) {
          (_, final String message) => Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WishtickErrorText(message),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => unawaited(
                    ref.read(inviteProvider(widget.token).notifier).refresh(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          (final PublicInvite loaded, _) => _Body(
            invite: loaded,
            busy: state.busy,
            // What this guest has already offered to this event, if anything.
            // Offering used to end with one snackbar and no way to find out
            // what became of it.
            myOffer: _myOfferFor(loaded.eventId),
            onRespond: (r) => unawaited(_respond(r)),
            onAddWishlist: () async {
              await offerWishlistToEvent(context, ref, loaded.eventId);
              // The row below it reports the offer's state, so it has to be
              // re-read once one has been made.
              ref.invalidate(myEventWishlistRequestsProvider);
            },
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.invite,
    required this.busy,
    required this.myOffer,
    required this.onRespond,
    required this.onAddWishlist,
  });

  final PublicInvite invite;
  final bool busy;
  final ValueChanged<RsvpResponse> onRespond;

  /// This guest's own offer to this event, if they have made one.
  final EventWishlistRequest? myOffer;

  /// Offering one of your own wishlists. Handed down rather than done here:
  /// only the stateful parent holds the ref and the invite's event.
  final VoidCallback onAddWishlist;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final event = invite.event;
    final host = invite.hostFirstName;
    final startsAt = event.startsAt.toLocal();
    final daysAway = DateTime(
      startsAt.year,
      startsAt.month,
      startsAt.day,
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;

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
                [
                  DateFormat('d MMM').format(startsAt),
                  if (daysAway > 0)
                    '$daysAway Days Left'
                  else if (daysAway == 0)
                    'Today',
                ].join(' • '),
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (host != null)
                Text(
                  'Hosted by $host',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (event.isCancelled) ...[
          _CancelledBanner(),
          const SizedBox(height: AppSpacing.lg),
        ],
        // The invitation the host made, whole and at its own proportions —
        // it is the point of this screen. A fixed 3:4 box cropped the last
        // line off every card of another shape, and reading `coverUrl` alone
        // drew nothing at all: an event made in the app has a card and no
        // cover. Absent when the host made neither.
        if (event.artworkUrl != null)
          SizedBox(
            width: double.infinity,
            child: WishtickImage(
              url: event.artworkUrl,
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
        if (host != null) ...[
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
        // Where, then when. The venue used to be missing here entirely — the
        // server had carried it for a while and this view never read it, so
        // every invitation told a guest a time and no place.
        if (event.venue != null && event.venue!.trim().isNotEmpty) ...[
          _IconLine(icon: Icons.place_outlined, text: event.venue!),
          const SizedBox(height: AppSpacing.sm),
        ],
        _IconLine(
          icon: Icons.schedule,
          text: DateFormat('EEE, d MMM • h:mm a').format(startsAt),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (!event.isCancelled) ...[
          Text(
            invite.hasResponded ? 'Your RSVP' : 'Are you coming?',
            style: context.text.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final option in RsvpResponse.answerable) ...[
                Expanded(
                  child: _RsvpButton(
                    option: option,
                    selected: invite.rsvp == option,
                    enabled: !busy,
                    onTap: () => onRespond(option),
                  ),
                ),
                if (option != RsvpResponse.answerable.last)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
        Text(
          'Quick Suggestions',
          style: context.text.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (invite.wishlists.isEmpty)
          Text(
            invite.hasResponded
                ? 'The host has not shared a wishlist for this event.'
                : 'RSVP to see the wishlists the host has shared.',
            style: context.text.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          )
        else
          for (final wishlist in invite.wishlists)
            if (wishlist.locked)
              // Known to exist, and that is all. Tapping says why rather than
              // doing nothing: a dead row reads as a broken one.
              _SuggestionRow(
                icon: Icons.lock_outline,
                title: wishlist.title,
                subtitle: 'Private wishlist',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'This wishlist is private. Only the people its owner '
                      'invited can open it.',
                    ),
                  ),
                ),
              )
            else
              _SuggestionRow(
                icon: Icons.favorite_border,
                title: wishlist.title,
                subtitle: 'View the gifts on this list',
                onTap: () => unawaited(
                  context.push<void>(AppRoutes.publicWishlist(wishlist.slug!)),
                ),
              ),
        // Only once they are actually coming. The server accepts an offer
        // from Going and Maybe alone, so offering it to anyone who had merely
        // answered — a guest who said Can't go included — meant a row that
        // failed with "not found" when tapped.
        if (invite.rsvp.isAttending)
          if (myOffer == null)
            _SuggestionRow(
              icon: Icons.playlist_add,
              title: 'Add your wishlist',
              subtitle: 'The host decides whether it shows here',
              onTap: onAddWishlist,
            )
          else
            // What became of it. Before this the guest got one snackbar and
            // then had no way to tell whether the host had ever answered.
            _OfferStatusRow(offer: myOffer!, onOfferAnother: onAddWishlist),
        // `291:1008`'s Group Gifts row. Drawn only when a group is actually
        // running: an invitee cannot start one from here, so an empty row
        // would be an affordance for nothing.
        if (invite.groupGifts.isNotEmpty)
          _SuggestionRow(
            icon: Icons.card_giftcard,
            title: 'Group Gifts',
            subtitle: invite.groupGifts.length == 1
                ? '1 active gift'
                : '${invite.groupGifts.length} active gifts',
            onTap: () => unawaited(_openGroupGift(context, invite.groupGifts)),
          ),
        // Guest List and Add Your Wish are the mock's remaining two rows. A
        // guest list is host-only information this view deliberately withholds,
        // and "Add Your Wish" is an action on the invitee's *own* list rather
        // than on this event — so neither is drawn as a row that cannot open.
      ],
    );
  }
}

/// Where the guest's own offered wishlist has got to.
///
/// A row rather than a snackbar, because the answer arrives minutes or days
/// after the offer: the host has to open the event and decide.
class _OfferStatusRow extends StatelessWidget {
  const _OfferStatusRow({required this.offer, required this.onOfferAnother});

  final EventWishlistRequest offer;

  /// A declined or withdrawn list frees the guest to offer a different one.
  final VoidCallback onOfferAnother;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, tint, line) = switch (offer.status) {
      EventWishlistRequestStatus.pending => (
        Icons.hourglass_empty,
        colors.warning,
        'Waiting for the host to accept it',
      ),
      EventWishlistRequestStatus.approved => (
        Icons.check_circle_outline,
        colors.success,
        'Showing on this event',
      ),
      EventWishlistRequestStatus.rejected => (
        Icons.do_not_disturb_on_outlined,
        colors.textMuted,
        'The host did not add this one',
      ),
      EventWishlistRequestStatus.removed => (
        Icons.remove_circle_outline,
        colors.textMuted,
        'Taken off this event',
      ),
    };
    // Only a list that is not on the event leaves the guest free to offer
    // another; a pending or showing one is already spoken for.
    final canOfferAnother =
        offer.status == EventWishlistRequestStatus.rejected ||
        offer.status == EventWishlistRequestStatus.removed;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: AppSizes.avatarMd,
              height: AppSizes.avatarMd,
              decoration: BoxDecoration(
                color: colors.primarySubtle,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: tint),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.wishlistTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    line,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (canOfferAnother)
              TextButton(
                onPressed: onOfferAnother,
                child: const Text('Offer another'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens a group gift, asking which one when there is more than one.
///
/// A sheet rather than a list screen: the design has no frame for "the group
/// gifts of an event", and with one gift — which is what `291:1008` draws —
/// there is nothing to choose and the sheet never appears.
Future<void> _openGroupGift(
  BuildContext context,
  List<InviteGroupGift> gifts,
) async {
  if (gifts.length == 1) {
    await context.push<void>(AppRoutes.groupGift(gifts.single.id));
    return;
  }

  final picked = await showModalBottomSheet<InviteGroupGift>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final gift in gifts)
            ListTile(
              leading: const Icon(Icons.card_giftcard),
              title: Text(gift.title),
              onTap: () => Navigator.of(sheetContext).pop(gift),
            ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  await context.push<void>(AppRoutes.groupGift(picked.id));
}

class _CancelledBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.dangerSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        'This event has been cancelled.',
        style: context.text.bodyMedium?.copyWith(color: colors.danger),
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
    return Row(
      children: [
        Icon(icon, size: AppSizes.iconMd, color: context.headlineBrandColor),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.text.titleSmall?.copyWith(
              color: context.headlineBrandColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _RsvpButton extends StatelessWidget {
  const _RsvpButton({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final RsvpResponse option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return selected
        ? ElevatedButton(
            onPressed: enabled ? onTap : null,
            child: Text(
              option.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : OutlinedButton(
            onPressed: enabled ? onTap : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              foregroundColor: colors.primary,
            ),
            child: Text(
              option.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: AppSizes.avatarMd,
                  height: AppSizes.avatarMd,
                  decoration: BoxDecoration(
                    color: colors.primarySubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: colors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.text.titleSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
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
                Icon(Icons.chevron_right, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
