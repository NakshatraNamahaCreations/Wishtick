import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/events_repository.dart';
import '../domain/event.dart';

/// The host's own events.
final myEventsProvider = FutureProvider.autoDispose<List<WishtickEventDetail>>(
  (ref) => ref.watch(eventsRepositoryProvider).listMine(),
);

/// One event, by id.
final eventDetailProvider = FutureProvider.autoDispose
    .family<WishtickEventDetail, String>(
      (ref, id) => ref.watch(eventsRepositoryProvider).get(id),
    );

/// The guest list for one event.
///
/// Keyed by the event id alone — a record key holding a filter would break
/// value equality and refetch forever; filtering happens in the widget.
final eventInvitesProvider = FutureProvider.autoDispose
    .family<List<EventInvite>, String>(
      (ref, eventId) => ref.watch(eventsRepositoryProvider).invites(eventId),
    );
