import 'package:flutter/foundation.dart';

enum EventType {
  birthday('birthday'),
  anniversary('anniversary'),
  generic('generic'),
  special('special');

  const EventType(this.wireValue);

  final String wireValue;

  static EventType fromWire(String? value) => EventType.values.firstWhere(
    (v) => v.wireValue == value,
    orElse: () => generic,
  );
}

enum EventStatus {
  draft('draft'),
  published('published'),
  completed('completed'),
  cancelled('cancelled');

  const EventStatus(this.wireValue);

  final String wireValue;

  static EventStatus fromWire(String? value) => EventStatus.values.firstWhere(
    (v) => v.wireValue == value,
    orElse: () => draft,
  );
}

enum RsvpResponse {
  pending('pending'),
  yes('yes'),
  no('no'),
  maybe('maybe');

  const RsvpResponse(this.wireValue);

  final String wireValue;

  static RsvpResponse fromWire(String? value) => RsvpResponse.values.firstWhere(
    (v) => v.wireValue == value,
    orElse: () => pending,
  );
}

/// An event, from either `GET /events/mine` (hosted) or `GET /events/invited`.
///
/// The two endpoints return different shapes; this is the union Home's
/// "Upcoming Events" rail needs, with [isHosting] recording which one it came
/// from. The backend has no venue field — "venue" lives only as a free-text
/// slot inside an invite template — so there is deliberately no location here.
@immutable
class WishtickEvent {
  const WishtickEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.startsAt,
    required this.timezone,
    required this.coverUrl,
    required this.isHosting,
    this.inviteMediaUrl,
    this.description,
    this.status,
    this.attendingCount,
    this.hostName,
    this.myRsvp,
    this.inviteToken,
  });

  final String id;
  final String title;
  final EventType type;
  final DateTime startsAt;

  /// IANA, e.g. `Asia/Kolkata`.
  final String timezone;
  final String? coverUrl;

  /// The invitation the host made. Most events carry this and no cover, so
  /// the rail draws it first — see [artworkUrl].
  final String? inviteMediaUrl;

  /// True when this came from `/events/mine`, false from `/events/invited`.
  final bool isHosting;

  final String? description;

  /// Hosted events only.
  final EventStatus? status;
  final int? attendingCount;

  /// Invited events only.
  final String? hostName;
  final RsvpResponse? myRsvp;

  /// Invited events only — *your* invite token, which is what lets the app
  /// open the invite screen without asking you to find the original link.
  final String? inviteToken;

  /// What to draw on the card: the invitation, else the cover, else nothing.
  String? get artworkUrl => inviteMediaUrl ?? coverUrl;

  /// Whole days until the event; negative once it has passed.
  int daysAway({DateTime? now}) {
    final today = now ?? DateTime.now();
    return DateTime(
      startsAt.year,
      startsAt.month,
      startsAt.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  factory WishtickEvent.fromHosted(Map<String, dynamic> json) => WishtickEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    type: EventType.fromWire(json['type'] as String?),
    startsAt: DateTime.parse(json['startsAt'] as String),
    timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
    coverUrl: json['coverUrl'] as String?,
    inviteMediaUrl: json['inviteMediaUrl'] as String?,
    isHosting: true,
    description: json['description'] as String?,
    status: EventStatus.fromWire(json['status'] as String?),
    attendingCount:
        (json['rsvpCounts'] as Map<String, dynamic>?)?['attending'] as int?,
  );

  factory WishtickEvent.fromInvited(Map<String, dynamic> json) => WishtickEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    type: EventType.fromWire(json['type'] as String?),
    startsAt: DateTime.parse(json['startsAt'] as String),
    timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
    coverUrl: json['coverUrl'] as String?,
    inviteMediaUrl: json['inviteMediaUrl'] as String?,
    isHosting: false,
    hostName: json['hostName'] as String?,
    myRsvp: RsvpResponse.fromWire(json['myRsvp'] as String?),
    inviteToken: json['inviteToken'] as String?,
  );
}
