import 'package:flutter/foundation.dart';

import '../../../core/media/media_repository.dart';

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

  /// Whether this counts as coming.
  ///
  /// The server lets only these two offer a wishlist to the event, so the app
  /// has to agree: it used to offer the row to anyone who had answered at all,
  /// and a guest who had declined got a "not found" error for their trouble.
  bool get isAttending => this == yes || this == maybe;
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
    this.venue,
    this.inviteMediaUrl,
  });

  final String title;
  final EventType type;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? timezone;
  final String? description;
  final String? coverUrl;
  final EventStatus status;

  /// Where it is happening. The invitation used to show a time and no place:
  /// the server has sent this for a while, and this view was not reading it.
  final String? venue;

  /// The card the host made (`2248:70`). Most events carry this and no cover,
  /// so it is what the invitation draws — see [artworkUrl].
  final String? inviteMediaUrl;

  bool get isCancelled => status == EventStatus.cancelled;

  /// The artwork to show the guest: the host's invitation, else the event's
  /// cover, else nothing. Null for a file no widget can draw — an MP4 or a
  /// PDF invitation — which the screen describes in words instead.
  String? get artworkUrl {
    final invitation = inviteMediaUrl;
    if (invitation != null && MediaRepository.isDrawableImage(invitation)) {
      return invitation;
    }
    return coverUrl;
  }

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
    venue: json['venue'] as String?,
    inviteMediaUrl: json['inviteMediaUrl'] as String?,
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
  const InviteWishlistLink({
    required this.slug,
    required this.title,
    this.locked = false,
  });

  /// Null when [locked]: there is nothing a locked row should let anyone try.
  final String? slug;
  final String title;

  /// A list the host put on the event that this viewer may not open — usually
  /// one a guest made *for* the host and kept private. Shown so guests know
  /// it exists, and only that.
  final bool locked;

  factory InviteWishlistLink.fromJson(Map<String, dynamic> json) =>
      InviteWishlistLink(
        slug: json['slug'] as String?,
        title: json['title'] as String,
        locked: json['locked'] as bool? ?? false,
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
    required this.eventId,
    required this.event,
    required this.hostFirstName,
    required this.inviteeName,
    required this.rsvp,
    required this.plusOnes,
    required this.wishlists,
    required this.groupGifts,
  });

  /// The event behind the token. Needed to offer a wishlist to it; the rest
  /// of this view stays token-scoped.
  final String eventId;
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
      eventId: json['eventId'] as String? ?? '',
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
