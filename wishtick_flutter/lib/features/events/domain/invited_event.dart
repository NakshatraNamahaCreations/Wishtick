import 'package:flutter/foundation.dart';

// `public_invite.dart` re-declares both of these; its versions carry the
// display labels the RSVP pills need, so they are the ones used here.
import 'public_invite.dart';

/// An event someone else invited you to (`GET /events/invited`).
///
/// Distinct from [WishtickEventDetail], which is an event you *host*: this
/// carries no guest list, no invite templates and no editing surface — only
/// enough to render the card and open the invite.
@immutable
class InvitedEvent {
  const InvitedEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.startsAt,
    required this.timezone,
    required this.coverUrl,
    required this.hostName,
    required this.myRsvp,
    required this.inviteToken,
  });

  final String id;
  final String title;
  final EventType type;
  final DateTime startsAt;
  final String timezone;
  final String? coverUrl;
  final String? hostName;
  final RsvpResponse myRsvp;

  /// This guest's own invite token — what deep-links them into the invite.
  final String? inviteToken;

  bool get hasAnswered => myRsvp != RsvpResponse.pending;

  factory InvitedEvent.fromJson(Map<String, dynamic> json) => InvitedEvent(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    type: EventType.fromWire(json['type'] as String?),
    startsAt: DateTime.parse(json['startsAt'] as String),
    timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
    coverUrl: json['coverUrl'] as String?,
    hostName: json['hostName'] as String?,
    myRsvp: RsvpResponse.fromWire(json['myRsvp'] as String?),
    inviteToken: json['inviteToken'] as String?,
  );
}
