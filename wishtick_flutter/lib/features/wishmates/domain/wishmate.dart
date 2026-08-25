import 'package:flutter/foundation.dart';

/// Where the viewer stands with someone — what decides a profile's buttons.
enum WishmateRelationship {
  /// No link at all. The profile offers "Add WishMate" (`4177:217`).
  none('none'),

  /// The viewer asked and is waiting.
  requestSent('request_sent'),

  /// They asked the viewer.
  requestReceived('request_received'),

  /// Connected. The profile offers "Remove WishMate" (`4177:267`).
  wishmates('wishmates'),

  /// The viewer looking at themselves. No relationship buttons at all.
  self('self');

  const WishmateRelationship(this.wireValue);

  final String wireValue;

  /// Falls back to [none] rather than throwing: a relationship the server
  /// learns to describe before this build shipped should render as "not
  /// connected", which offers a way forward, not as a crash.
  static WishmateRelationship fromWire(String? value) => WishmateRelationship
      .values
      .firstWhere((v) => v.wireValue == value, orElse: () => none);
}

/// How one person appears to another, with nothing viewer-relative attached.
///
/// Everything here is public by design — a handle, a name and a photo are what
/// search and request screens show about someone you have not connected to.
/// The server builds this shape explicitly so nothing that identifies a person
/// off-platform can leak into it.
///
/// Split from [Wishmate] for the same reason the backend splits it: not every
/// caller has a viewer to be relative to. A chat-list row names the person on
/// the other side of a thread and has no use for a mutual count, and sending
/// zero there would be a number that is wrong rather than absent.
@immutable
class PersonIdentity {
  const PersonIdentity({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.photoUrl,
    required this.online,
    required this.lastSeenAt,
  });

  final String userId;

  /// Null for an account that never claimed one. Such an account is not
  /// discoverable, so this is only ever null for someone reached another way.
  final String? username;

  final String? displayName;
  final String? photoUrl;

  /// Whether they hold a live socket right now — the green dot. Arrives on
  /// every row, so no screen needs a second call to draw presence.
  final bool online;

  final DateTime? lastSeenAt;

  /// The `@handle`, or a placeholder for the handle-less.
  String get handle => username == null ? '@—' : '@$username';

  /// What a row's primary line shows. Falls back through name → handle → a
  /// neutral word, so a row is never blank.
  String get name {
    final trimmed = displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (username != null) return '@$username';
    return 'Wishtick user';
  }

  /// "Online", or when they were last seen — the subtitle on `4177:6`.
  String presenceLabel({DateTime? now}) {
    if (online) return 'Online';
    final seen = lastSeenAt;
    if (seen == null) return 'Offline';
    final ago = (now ?? DateTime.now()).difference(seen);
    if (ago.inMinutes < 1) return 'Last seen just now';
    if (ago.inMinutes < 60) return 'Last seen ${ago.inMinutes}m ago';
    if (ago.inHours < 24) return 'Last seen ${ago.inHours}h ago';
    return 'Last seen ${ago.inDays}d ago';
  }

  factory PersonIdentity.fromJson(Map<String, dynamic> json) => PersonIdentity(
    userId: json['userId'] as String,
    username: json['username'] as String?,
    displayName: json['displayName'] as String?,
    photoUrl: json['photoUrl'] as String?,
    online: json['online'] as bool? ?? false,
    lastSeenAt: json['lastSeenAt'] == null
        ? null
        : DateTime.tryParse(json['lastSeenAt'] as String),
  );
}

/// An identity plus how the viewer stands beside it.
@immutable
class Wishmate extends PersonIdentity {
  const Wishmate({
    required super.userId,
    required super.username,
    required super.displayName,
    required super.photoUrl,
    required this.mutualCount,
    required super.online,
    required super.lastSeenAt,
  });

  /// How many accepted WishMates the viewer and this person share.
  final int mutualCount;

  /// "4 mutual friends" / "1 mutual friend", or null when they share none —
  /// the frames omit the line entirely rather than printing a zero.
  String? get mutualLine => switch (mutualCount) {
    0 => null,
    1 => '1 mutual friend',
    _ => '$mutualCount mutual friends',
  };

  factory Wishmate.fromJson(Map<String, dynamic> json) => Wishmate(
    userId: json['userId'] as String,
    username: json['username'] as String?,
    displayName: json['displayName'] as String?,
    photoUrl: json['photoUrl'] as String?,
    mutualCount: json['mutualCount'] as int? ?? 0,
    online: json['online'] as bool? ?? false,
    lastSeenAt: json['lastSeenAt'] == null
        ? null
        : DateTime.tryParse(json['lastSeenAt'] as String),
  );
}

/// One pending request, in either direction.
///
/// Received and Sent are the same row seen from opposite ends, which is why
/// there is one type and not two: [person] is whoever is *not* the viewer.
@immutable
class WishLink {
  const WishLink({
    required this.linkId,
    required this.person,
    required this.createdAt,
  });

  final String linkId;
  final Wishmate person;
  final DateTime createdAt;

  factory WishLink.fromJson(Map<String, dynamic> json) => WishLink(
    linkId: json['linkId'] as String,
    person: Wishmate.fromJson(json['person'] as Map<String, dynamic>),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// One "Recent Activity" card on `4177:267` — an event the viewer and this
/// person are both going to.
///
/// Only that intersection ever arrives: someone's calendar is not public, and
/// the server's rule is that you are shown what you were already shown. A
/// viewer who shares no event with this person gets an empty list, which is
/// why the section is hidden rather than drawn empty.
@immutable
class WishmateActivity {
  const WishmateActivity({
    required this.eventId,
    required this.title,
    required this.startsAt,
    required this.venue,
    required this.rsvp,
  });

  final String eventId;
  final String title;
  final DateTime startsAt;
  final String? venue;

  /// Their answer — only `yes` or `maybe` ever reach here.
  final String rsvp;

  /// The pill above the title: "Attending in 3 days", "Attending today".
  ///
  /// Counted in whole days from the start of today so that "tomorrow" does not
  /// become "in 0 days" for an event a few hours after midnight.
  String attendingLabel({DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final days = _dateOnly(startsAt).difference(today).inDays;
    return switch (days) {
      <= 0 => 'Attending today',
      1 => 'Attending tomorrow',
      _ => 'Attending in $days days',
    };
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  factory WishmateActivity.fromJson(Map<String, dynamic> json) =>
      WishmateActivity(
        eventId: json['eventId'] as String,
        title: json['title'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        venue: json['venue'] as String?,
        rsvp: json['rsvp'] as String? ?? 'yes',
      );
}

/// The public profile screen (`4177:217` / `4177:267`).
@immutable
class WishmateProfile {
  const WishmateProfile({
    required this.person,
    required this.relationship,
    required this.city,
    required this.country,
    required this.joinedAt,
    required this.mutuals,
    required this.recentActivity,
  });

  final Wishmate person;
  final WishmateRelationship relationship;
  final String? city;
  final String? country;
  final DateTime joinedAt;

  /// A handful of the mutual WishMates, for the avatar stack beside the count.
  /// The total is [Wishmate.mutualCount]; this is only what the stack draws.
  final List<Wishmate> mutuals;

  final List<WishmateActivity> recentActivity;

  /// "Banglore, Karnataka, India" — the location row of "About This Profile".
  /// Null when the person has filled in neither field, which hides the row.
  String? get location {
    final parts = [
      city,
      country,
    ].where((p) => p != null && p.trim().isNotEmpty).map((p) => p!.trim());
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Whether "Message" can open a thread. The backend refuses a direct chat
  /// without an accepted link, so the button is offered but inert otherwise —
  /// see `PersonProfileScreen`.
  bool get canMessage => relationship == WishmateRelationship.wishmates;

  factory WishmateProfile.fromJson(Map<String, dynamic> json) =>
      WishmateProfile(
        person: Wishmate.fromJson(json['person'] as Map<String, dynamic>),
        relationship: WishmateRelationship.fromWire(
          json['relationship'] as String?,
        ),
        city: json['city'] as String?,
        country: json['country'] as String?,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        mutuals:
            (json['mutuals'] as List<dynamic>?)
                ?.map((e) => Wishmate.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        recentActivity:
            (json['recentActivity'] as List<dynamic>?)
                ?.map(
                  (e) => WishmateActivity.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            const [],
      );
}
