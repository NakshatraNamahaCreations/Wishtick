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
    orElse: () => published,
  );
}

enum RsvpResponse {
  pending('pending', 'Pending'),
  yes('yes', 'Going'),
  no('no', "Can't go"),
  maybe('maybe', 'Maybe');

  const RsvpResponse(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static RsvpResponse fromWire(String? value) => RsvpResponse.values.firstWhere(
    (v) => v.wireValue == value,
    orElse: () => pending,
  );

  /// The three a guest can actually pick. `pending` is a state, not an answer.
  static const answerable = [yes, maybe, no];
}

@immutable
class InviteEvent {
  const InviteEvent({
    required this.title,
    required this.type,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.description,
    required this.coverUrl,
    required this.status,
  });

  final String title;
  final EventType type;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? timezone;
  final String? description;
  final String? coverUrl;
  final EventStatus status;

  bool get isCancelled => status == EventStatus.cancelled;

  factory InviteEvent.fromJson(Map<String, dynamic> json) => InviteEvent(
    title: json['title'] as String,
    type: EventType.fromWire(json['type'] as String?),
    startsAt: DateTime.parse(json['startsAt'] as String),
    endsAt: json['endsAt'] == null
        ? null
        : DateTime.parse(json['endsAt'] as String),
    timezone: json['timezone'] as String?,
    description: json['description'] as String?,
    coverUrl: json['coverUrl'] as String?,
    status: EventStatus.fromWire(json['status'] as String?),
  );
}

/// A wishlist the host attached and this invitee is allowed to open.
///
/// The backend resolves each one through its access policy, so an event-only
/// list simply isn't in the array until the guest has RSVP'd — the client never
/// has to decide what to hide.
@immutable
class InviteWishlistLink {
  const InviteWishlistLink({required this.slug, required this.title});

  final String slug;
  final String title;

  factory InviteWishlistLink.fromJson(Map<String, dynamic> json) =>
      InviteWishlistLink(
        slug: json['slug'] as String,
        title: json['title'] as String,
      );
}

/// A group gift running for the event, as `291:1008` lists it.
@immutable
class InviteGroupGift {
  const InviteGroupGift({required this.id, required this.title});

  final String id;
  final String title;

  factory InviteGroupGift.fromJson(Map<String, dynamic> json) =>
      InviteGroupGift(id: json['id'] as String, title: json['title'] as String);
}

/// What an invite token resolves to (`PublicInviteView`).
///
/// Heavily redacted: the host is a first name and nothing else, and there is no
/// guest list — an invitee learns about the party, not about everyone else
/// invited to it.
@immutable
class PublicInvite {
  const PublicInvite({
    required this.event,
    required this.hostFirstName,
    required this.inviteeName,
    required this.rsvp,
    required this.plusOnes,
    required this.wishlists,
    required this.groupGifts,
  });

  final InviteEvent event;
  final String? hostFirstName;
  final String? inviteeName;
  final RsvpResponse rsvp;
  final int plusOnes;
  final List<InviteWishlistLink> wishlists;

  /// Open groups an invitee could still join. Id and title only — the amounts
  /// and who has paid stay behind the group's own endpoint.
  final List<InviteGroupGift> groupGifts;

  bool get hasResponded => rsvp != RsvpResponse.pending;

  factory PublicInvite.fromJson(Map<String, dynamic> json) {
    final invitee = json['invitee'] as Map<String, dynamic>? ?? const {};
    final host = json['host'] as Map<String, dynamic>? ?? const {};
    return PublicInvite(
      event: InviteEvent.fromJson(json['event'] as Map<String, dynamic>),
      hostFirstName: host['firstName'] as String?,
      inviteeName: invitee['name'] as String?,
      rsvp: RsvpResponse.fromWire(invitee['rsvp'] as String?),
      plusOnes: invitee['plusOnes'] as int? ?? 0,
      wishlists: (json['wishlists'] as List<dynamic>? ?? const [])
          .map((e) => InviteWishlistLink.fromJson(e as Map<String, dynamic>))
          .toList(),
      groupGifts: (json['groupGifts'] as List<dynamic>? ?? const [])
          .map((e) => InviteGroupGift.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
