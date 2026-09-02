import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../wishlist/data/wishlist_repository.dart';
import '../../data/events_repository.dart';
import '../../domain/event_wishlist_request.dart';

/// The wishlists guests have offered to one event — the host's queue.
final eventWishlistRequestsProvider =
    FutureProvider.family<List<EventWishlistRequest>, String>((ref, eventId) {
      return ref.watch(eventsRepositoryProvider).wishlistRequests(eventId);
    });

/// The caller's own offers, so a guest can see what is still waiting.
final myEventWishlistRequestsProvider =
    FutureProvider<List<EventWishlistRequest>>((ref) {
      return ref.watch(eventsRepositoryProvider).myWishlistRequests();
    });

/// "Guest Wishlists" on the host's event page.
///
/// Draws nothing when nobody has offered one: an empty section on every event
/// is an affordance for a thing the host cannot do anything about.
class EventWishlistRequestsSection extends ConsumerStatefulWidget {
  const EventWishlistRequestsSection({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<EventWishlistRequestsSection> createState() =>
      _EventWishlistRequestsSectionState();
}

class _EventWishlistRequestsSectionState
    extends ConsumerState<EventWishlistRequestsSection> {
  /// Which row is mid-answer, so its buttons go inert together and a double
  /// tap cannot send approve and decline for the same offer.
  String? _answering;

  Future<void> _act(
    EventWishlistRequest request,
    Future<void> Function(EventsRepository repo) send,
  ) async {
    if (_answering != null) return;
    setState(() => _answering = request.id);
    try {
      await send(ref.read(eventsRepositoryProvider));
      if (!mounted) return;
      ref.invalidate(eventWishlistRequestsProvider(widget.eventId));
    } on ApiException catch (e) {
      if (!mounted) return;
      // Refetch either way: the usual refusal is that the owner withdrew it or
      // answered on another device, and both make the queue stale.
      ref.invalidate(eventWishlistRequestsProvider(widget.eventId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _answering = null);
    }
  }

  Future<bool> _confirmRemoval(EventWishlistRequest request) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this wishlist?'),
        content: Text(
          '${request.wishlistTitle} will stop showing on this event, and '
          '${request.requestedByName} will have to offer it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Remove',
              style: TextStyle(color: context.colors.danger),
            ),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final requests =
        ref.watch(eventWishlistRequestsProvider(widget.eventId)).value ??
        const <EventWishlistRequest>[];
    if (requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Guest Wishlists',
          style: context.text.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final request in requests)
          _RequestRow(
            request: request,
            busy: _answering == request.id,
            onApprove: () => unawaited(
              _act(
                request,
                (repo) => repo.respondToWishlistRequest(
                  widget.eventId,
                  request.id,
                  approve: true,
                ),
              ),
            ),
            onReject: () => unawaited(
              _act(
                request,
                (repo) => repo.respondToWishlistRequest(
                  widget.eventId,
                  request.id,
                  approve: false,
                ),
              ),
            ),
            onRemove: () async {
              if (!await _confirmRemoval(request)) return;
              await _act(
                request,
                (repo) =>
                    repo.removeWishlistRequest(widget.eventId, request.id),
              );
            },
          ),
      ],
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onRemove,
  });

  final EventWishlistRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = request.itemLine;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.wishlistTitle,
            style: context.text.bodyLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            // Who offered it, and how much is on it — the two things the host
            // is actually deciding between.
            items == null
                ? '${request.requestedByName} offered this list'
                : '${request.requestedByName} offered this list · $items',
            style: context.text.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (request.status.isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : onApprove,
                    child: const Text('Show on event'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: AppSizes.iconSm,
                  color: colors.success,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Showing on this event',
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : () => unawaited(onRemove()),
                  child: const Text('Remove'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Offers one of the guest's own wishlists to an event they are going to.
///
/// Picks from lists that are not already on an event — the server refuses one
/// that is, and offering a list only to be told it is spoken for is a worse
/// way to learn that than not being offered it.
Future<void> offerWishlistToEvent(
  BuildContext context,
  WidgetRef ref,
  String eventId,
) async {
  final lists = await ref.read(wishlistRepositoryProvider).listMine();
  if (!context.mounted) return;

  final offerable = lists.where((w) => w.eventId == null).toList();
  if (offerable.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have no wishlist free to add to this event.'),
      ),
    );
    return;
  }

  final picked = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _WishlistOfferSheet(titles: {for (final w in offerable) w.id: w.title}),
  );
  if (picked == null || !context.mounted) return;

  try {
    await ref.read(eventsRepositoryProvider).offerWishlist(eventId, picked);
    if (!context.mounted) return;
    ref.invalidate(myEventWishlistRequestsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sent to the host. It shows once they accept it.'),
      ),
    );
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
  }
}

class _WishlistOfferSheet extends StatelessWidget {
  const _WishlistOfferSheet({required this.titles});

  final Map<String, String> titles;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Material, not a coloured box: a ListTile paints its ink on the nearest
    // Material ancestor, so a plain container swallows every ripple.
    return Material(
      color: colors.background,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Which wishlist?',
                style: context.text.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in titles.entries)
                    ListTile(
                      title: Text(
                        entry.value,
                        style: context.text.bodyLarge?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(entry.key),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
