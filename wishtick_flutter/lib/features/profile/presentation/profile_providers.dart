import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../events/presentation/event_providers.dart';
import '../../gifting/presentation/gift_list_providers.dart';
import '../data/profile_repository.dart';
import '../domain/me.dart';

/// The signed-in user's profile.
///
/// Not `autoDispose`: the Profile hub, Edit Profile and the greeting all read
/// it, and it changes only when the user edits it — refetching on every
/// navigation between those three would be pure waste.
final meProvider = FutureProvider<Me>((ref) {
  return ref.watch(profileRepositoryProvider).getMe();
});

/// The three counters across the top of the Profile hub (`64:158`).
///
/// Derived from the lists the hub links to rather than a dedicated endpoint:
/// the numbers must agree with what those screens show, and a separate count
/// query is exactly how the two drift apart.
@immutable
class ProfileCounts {
  const ProfileCounts({
    required this.given,
    required this.received,
    required this.eventsAndInvites,
  });

  final int? given;
  final int? received;
  final int? eventsAndInvites;
}

final profileCountsProvider = Provider<ProfileCounts>((ref) {
  return ProfileCounts(
    given: ref.watch(giftListProvider(GiftListKind.given)).value?.length,
    received: ref.watch(giftListProvider(GiftListKind.received)).value?.length,
    eventsAndInvites: switch ((
      ref.watch(myEventsProvider).value,
      ref.watch(invitedEventsProvider).value,
    )) {
      // Both rails must be in before a total means anything — showing the
      // hosted count alone would read as a wrong number, not a loading one.
      (final hosted?, final invited?) => hosted.length + invited.length,
      _ => null,
    },
  );
});
