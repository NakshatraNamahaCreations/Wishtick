import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wishmates_repository.dart';
import '../domain/wishmate.dart';

/// `4177:138`'s "My WishMates (6)".
final wishmatesProvider = FutureProvider<List<Wishmate>>((ref) {
  return ref.watch(wishmatesRepositoryProvider).listMates();
});

/// The "N New Requests" banner's number.
///
/// Its own call rather than `listReceived().length`: the banner sits above a
/// list that is already a round trip, and the count endpoint exists precisely
/// so the list screen does not have to fetch every request to draw one line.
final pendingRequestCountProvider = FutureProvider<int>((ref) {
  return ref.watch(wishmatesRepositoryProvider).pendingCount();
});

/// `4177:77` — requests addressed to me.
final receivedWishLinksProvider = FutureProvider<List<WishLink>>((ref) {
  return ref.watch(wishmatesRepositoryProvider).listReceived();
});

/// `4177:111` — requests I sent that are still waiting.
final sentWishLinksProvider = FutureProvider<List<WishLink>>((ref) {
  return ref.watch(wishmatesRepositoryProvider).listSent();
});

/// "People You May Know", which every screen in this sprint shows a rail of.
final peopleSuggestionsProvider = FutureProvider<List<Wishmate>>((ref) {
  return ref.watch(wishmatesRepositoryProvider).suggestions();
});

/// One person's profile (`4177:217` / `4177:267`).
final personProfileProvider = FutureProvider.family<WishmateProfile, String>((
  ref,
  userId,
) {
  return ref.watch(wishmatesRepositoryProvider).profile(userId);
});

/// Search results for `4177:42`.
///
/// The server returns nothing for a term under two characters, so the family
/// key is the raw query and the screen debounces before changing it — a
/// provider per keystroke would fire a request per keystroke.
final peopleSearchProvider = FutureProvider.family<List<Wishmate>, String>((
  ref,
  query,
) {
  final trimmed = query.trim();
  if (trimmed.length < 2) return Future.value(const <Wishmate>[]);
  return ref.watch(wishmatesRepositoryProvider).search(trimmed);
});

/// Everything one graph mutation can change.
///
/// Accepting a single request changes the WishMates list, both WishLink tabs,
/// the banner count, the suggestions and any profile behind the back button —
/// so they are refetched together, and this list is the one place that knows
/// which "together" means. Adding a provider above means adding it here.
///
/// A list rather than a function taking a ref because [WidgetRef] and [Ref]
/// share no supertype exposing `invalidate`, and the type they both accept
/// (`ProviderOrFamily`) is not exported. Inference names it; we cannot.
final wishmateGraphProviders = [
  wishmatesProvider,
  pendingRequestCountProvider,
  receivedWishLinksProvider,
  sentWishLinksProvider,
  peopleSuggestionsProvider,
  personProfileProvider,
];

/// Refetches [wishmateGraphProviders] from a widget.
void invalidateWishmateGraph(WidgetRef ref) {
  for (final provider in wishmateGraphProviders) {
    ref.invalidate(provider);
  }
}
