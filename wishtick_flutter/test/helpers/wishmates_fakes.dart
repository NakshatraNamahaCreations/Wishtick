import 'dart:async';

import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/wishmates/data/wishmates_repository.dart';
import 'package:wishtick_flutter/features/wishmates/domain/wishmate.dart';

// ── Builders ────────────────────────────────────────────────────────────────

Wishmate buildWishmate({
  String userId = 'u_priyal',
  String? username = 'priyalsharma',
  String? displayName = 'Priyal Sharma',
  String? photoUrl,
  String? avatarKey,
  int mutualCount = 0,
  bool online = false,
  DateTime? lastSeenAt,
}) => Wishmate(
  userId: userId,
  username: username,
  displayName: displayName,
  photoUrl: photoUrl,
  avatarKey: avatarKey,
  mutualCount: mutualCount,
  online: online,
  lastSeenAt: lastSeenAt,
);

PersonIdentity buildIdentity({
  String userId = 'u_rohan',
  String? username = 'rohan_prasad',
  String? displayName = 'Rohan Prasad',
  String? photoUrl,
  String? avatarKey,
  bool online = false,
  DateTime? lastSeenAt,
}) => PersonIdentity(
  userId: userId,
  username: username,
  displayName: displayName,
  photoUrl: photoUrl,
  avatarKey: avatarKey,
  online: online,
  lastSeenAt: lastSeenAt,
);

WishLink buildWishLink({
  String linkId = 'link_1',
  Wishmate? person,
  DateTime? createdAt,
}) => WishLink(
  linkId: linkId,
  person: person ?? buildWishmate(),
  createdAt: createdAt ?? DateTime(2026, 8, 20),
);

WishmateActivity buildActivity({
  String eventId = 'ev_1',
  String title = 'Ananya’s Birthday',
  DateTime? startsAt,
  String? venue = 'Infinite Rooftop',
  String rsvp = 'yes',
}) => WishmateActivity(
  eventId: eventId,
  title: title,
  startsAt: startsAt ?? DateTime(2026, 7, 24),
  venue: venue,
  rsvp: rsvp,
);

WishmateProfile buildProfile({
  Wishmate? person,
  WishmateRelationship relationship = WishmateRelationship.none,
  String? city = 'Banglore, Karnataka',
  String? country = 'India',
  DateTime? joinedAt,
  List<Wishmate> mutuals = const [],
  List<WishmateActivity> recentActivity = const [],
}) => WishmateProfile(
  person: person ?? buildWishmate(),
  relationship: relationship,
  city: city,
  country: country,
  joinedAt: joinedAt ?? DateTime(2026, 7, 24),
  mutuals: mutuals,
  recentActivity: recentActivity,
);

// ── Fake ────────────────────────────────────────────────────────────────────

/// A [WishmatesRepository] that answers from memory and records what was asked
/// of it, so a screen test can assert the call as well as the repaint.
class FakeWishmatesRepository implements WishmatesRepository {
  FakeWishmatesRepository({
    this.mates = const [],
    this.received = const [],
    this.sent = const [],
    this.suggested = const [],
    this.results = const [],
    WishmateProfile? personProfile,
    this.pending = 0,
    this.failWith,
    this.usernameAvailable = true,
  }) : personProfile = personProfile ?? buildProfile();

  List<Wishmate> mates;
  List<WishLink> received;
  List<WishLink> sent;
  List<Wishmate> suggested;

  /// What [search] returns, whatever the term.
  List<Wishmate> results;

  /// Named around the field/method clash: [profile] is the repository call.
  WishmateProfile personProfile;

  int pending;

  /// Thrown by every method when set — the error paths are one branch, so one
  /// switch exercises them all.
  Object? failWith;

  bool usernameAvailable;

  /// Every mutation, in order: `accept:link_1`, `request:u_2`, …
  final calls = <String>[];

  /// What [setUsername] was last handed.
  String? claimedUsername;

  T _guard<T>(T value) {
    if (failWith != null) throw failWith!;
    return value;
  }

  @override
  Future<Wishmate> setUsername(String username) async {
    calls.add('setUsername:$username');
    claimedUsername = username;
    return _guard(buildWishmate(username: username));
  }

  /// Availability answers the test resolves by hand.
  ///
  /// Lets a *late* reply for an earlier term be made to land after a newer
  /// one — the race the claim screen's `_checking` guard exists for, and the
  /// only way to exercise it deterministically.
  final pendingAvailability = <String, Completer<bool>>{};

  @override
  Future<bool> isUsernameAvailable(String username) {
    calls.add('isAvailable:$username');
    final pending = pendingAvailability[username];
    if (pending != null) return pending.future;
    return Future.value(_guard(usernameAvailable));
  }

  @override
  Future<List<Wishmate>> search(String query, {int? limit}) async {
    calls.add('search:$query');
    return _guard(results);
  }

  @override
  Future<List<Wishmate>> suggestions() async => _guard(suggested);

  @override
  Future<WishmateProfile> profile(String userId) async {
    calls.add('profile:$userId');
    return _guard(personProfile);
  }

  @override
  Future<List<Wishmate>> listMates() async => _guard(mates);

  @override
  Future<int> pendingCount() async => _guard(pending);

  @override
  Future<List<WishLink>> listReceived() async => _guard(received);

  @override
  Future<List<WishLink>> listSent() async => _guard(sent);

  @override
  Future<WishmateRelationship> request(String userId) async {
    calls.add('request:$userId');
    return _guard(WishmateRelationship.requestSent);
  }

  @override
  Future<WishmateRelationship> accept(String linkId) async {
    calls.add('accept:$linkId');
    return _guard(WishmateRelationship.wishmates);
  }

  @override
  Future<WishmateRelationship> decline(String linkId) async {
    calls.add('decline:$linkId');
    return _guard(WishmateRelationship.none);
  }

  @override
  Future<void> withdraw(String linkId) async {
    calls.add('withdraw:$linkId');
    _guard(null);
  }

  @override
  Future<void> remove(String userId) async {
    calls.add('remove:$userId');
    _guard(null);
  }
}

/// The failure the screens render as a message rather than a crash.
const fakeApiFailure = ApiException(
  code: 'INTERNAL_ERROR',
  message: 'Something went wrong.',
);
