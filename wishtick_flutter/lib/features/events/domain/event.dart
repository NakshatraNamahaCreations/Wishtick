import 'package:flutter/foundation.dart';

import '../../wishmates/domain/wishmate.dart';

/// What kind of occasion this is. Drives which invite templates are offered.
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

enum EventVisibility {
  /// Anyone with the link.
  public('public'),

  /// Invitees only.
  private('private'),

  /// Invitees, plus anyone holding the share link.
  inviteOnly('invite_only');

  const EventVisibility(this.wireValue);

  final String wireValue;

  static EventVisibility fromWire(String? value) => EventVisibility.values
      .firstWhere((v) => v.wireValue == value, orElse: () => private);
}

enum EventStatus {
  /// Being composed. No invites go out, no reminders are scheduled.
  draft('draft'),
  published('published'),

  /// The date has passed. Set by the scheduler, never by a person.
  completed('completed'),
  cancelled('cancelled');

  const EventStatus(this.wireValue);

  final String wireValue;

  static EventStatus fromWire(String? value) => EventStatus.values.firstWhere(
    (v) => v.wireValue == value,
    orElse: () => draft,
  );

  /// Only a published event can be invited to.
  bool get acceptsInvites => this == published;
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

  /// The words the guest list uses (`4099:1256`), not the wire values.
  String get label => switch (this) {
    RsvpResponse.yes => 'Confirmed',
    RsvpResponse.maybe => 'May be',
    RsvpResponse.no => 'Declined',
    RsvpResponse.pending => 'No reply',
  };

  /// Whether this guest and their plus-ones are counted as coming.
  ///
  /// `pending` is excluded deliberately, matching the server: an unanswered
  /// invite means someone was *asked*, not that they are attending.
  bool get isAttending => this == yes || this == maybe;
}

/// The head-count card on `4099:1256`.
@immutable
class RsvpCounts {
  const RsvpCounts({
    required this.yes,
    required this.no,
    required this.maybe,
    required this.pending,
    required this.attending,
    required this.invited,
  });

  final int yes;
  final int no;
  final int maybe;
  final int pending;

  /// yes + maybe + their plus-ones. What a caterer would ask for.
  final int attending;

  final int invited;

  factory RsvpCounts.fromJson(Map<String, dynamic> json) => RsvpCounts(
    yes: json['yes'] as int? ?? 0,
    no: json['no'] as int? ?? 0,
    maybe: json['maybe'] as int? ?? 0,
    pending: json['pending'] as int? ?? 0,
    attending: json['attending'] as int? ?? 0,
    invited: json['invited'] as int? ?? 0,
  );

  static const empty = RsvpCounts(
    yes: 0,
    no: 0,
    maybe: 0,
    pending: 0,
    attending: 0,
    invited: 0,
  );
}

/// The invite design chosen for an event: which template, which colourway, and
/// the text filled into its slots.
@immutable
class InviteTemplateChoice {
  const InviteTemplateChoice({
    required this.templateId,
    required this.colorVariant,
    required this.fields,
  });

  final String templateId;
  final String colorVariant;
  final Map<String, String> fields;

  factory InviteTemplateChoice.fromJson(Map<String, dynamic> json) =>
      InviteTemplateChoice(
        templateId: json['templateId'] as String,
        colorVariant: json['colorVariant'] as String? ?? '',
        fields:
            (json['fields'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v as String),
            ) ??
            const {},
      );

  Map<String, dynamic> toJson() => {
    'templateId': templateId,
    'colorVariant': colorVariant,
    'fields': fields,
  };
}

/// The share link. Host-only — a guest list is not public information.
@immutable
class EventShare {
  const EventShare({required this.slug, required this.url});

  final String slug;
  final String url;

  factory EventShare.fromJson(Map<String, dynamic> json) =>
      EventShare(slug: json['slug'] as String, url: json['url'] as String);
}

/// An event the caller hosts.
@immutable
class WishtickEventDetail {
  const WishtickEventDetail({
    required this.id,
    required this.title,
    required this.type,
    required this.startsAt,
    required this.timezone,
    required this.visibility,
    required this.status,
    required this.wishlistIds,
    required this.createdAt,
    this.endsAt,
    this.description,
    this.venue,
    this.personName,
    this.relation,
    this.coverUrl,
    this.inviteMediaUrl,
    this.inviteTemplate,
    this.ogImageUrl,
    this.share,
    this.rsvpCounts,
    this.forSelf = false,
  });

  final String id;
  final String title;
  final EventType type;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String timezone;
  final String? description;

  /// Where it is happening (`257:755`). Free text — "Mysore Socials", not a
  /// geocoded address.
  final String? venue;

  /// Who the event is for, and how the host knows them (`257:733`).
  /// [relation] is a `relation` taxonomy key, not a label.
  final String? personName;
  final String? relation;

  /// The host is the person being celebrated — their own birthday, wedding.
  ///
  /// Decides two things: the create flow asks for no name and no relation,
  /// and the invitation carries no "Hosted by" line, because the host and the
  /// guest of honour are the same person.
  final bool forSelf;

  final String? coverUrl;

  /// The host's own invitation artwork (`2248:70`). When set it replaces the
  /// template card everywhere the invitation is shown — the host chose one
  /// path or the other, and showing both would be two invitations to one party.
  final String? inviteMediaUrl;

  final EventVisibility visibility;
  final EventStatus status;
  final List<String> wishlistIds;
  final InviteTemplateChoice? inviteTemplate;
  final String? ogImageUrl;
  final DateTime createdAt;

  /// Host-only, so its presence *is* the "can I manage this" capability —
  /// rather than a role guessed on the client.
  final EventShare? share;

  final RsvpCounts? rsvpCounts;

  bool get canManage => share != null;

  factory WishtickEventDetail.fromJson(Map<String, dynamic> json) =>
      WishtickEventDetail(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        type: EventType.fromWire(json['type'] as String?),
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: json['endsAt'] == null
            ? null
            : DateTime.parse(json['endsAt'] as String),
        timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
        description: json['description'] as String?,
        venue: json['venue'] as String?,
        personName: json['personName'] as String?,
        relation: json['relation'] as String?,
        coverUrl: json['coverUrl'] as String?,
        inviteMediaUrl: json['inviteMediaUrl'] as String?,
        visibility: EventVisibility.fromWire(json['visibility'] as String?),
        status: EventStatus.fromWire(json['status'] as String?),
        wishlistIds:
            (json['wishlistIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        inviteTemplate: json['inviteTemplate'] == null
            ? null
            : InviteTemplateChoice.fromJson(
                json['inviteTemplate'] as Map<String, dynamic>,
              ),
        ogImageUrl: json['ogImageUrl'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        share: json['share'] == null
            ? null
            : EventShare.fromJson(json['share'] as Map<String, dynamic>),
        rsvpCounts: json['rsvpCounts'] == null
            ? null
            : RsvpCounts.fromJson(json['rsvpCounts'] as Map<String, dynamic>),
        forSelf: json['forSelf'] as bool? ?? false,
      );
}

/// One row of the guest list (`4099:1256`).
@immutable
class EventInvite {
  const EventInvite({
    required this.id,
    required this.rsvp,
    required this.plusOnes,
    required this.createdAt,
    this.person,
    this.invitedUserId,
    this.message,
    this.respondedAt,
  });

  final String id;

  /// Who was invited.
  ///
  /// Replaces the old email/phone/name trio: invitations are addressed to a
  /// WishMate now, so the guest list shows the same face, name and handle the
  /// rest of the app shows. Null for an account that has since been deleted —
  /// the invite outlives the profile.
  final PersonIdentity? person;

  final String? invitedUserId;
  final RsvpResponse rsvp;

  /// Guests this person is bringing — the "+ 2 Guests" line on the row.
  final int plusOnes;

  final String? message;
  final DateTime? respondedAt;

  /// When they were added to the guest list — "Added on" (`4096:162`).
  final DateTime createdAt;

  /// What to call them on the guest list. Never blank, even for an account
  /// with nothing filled in.
  String get displayName => person?.name ?? 'Guest';

  /// Their `@handle`, where a contact address used to go. Null for a guest
  /// who never claimed one.
  String? get contact =>
      person?.username == null ? null : '@${person!.username}';

  /// This guest's contribution to the head count — nobody, unless they are
  /// coming.
  int get headCount => rsvp.isAttending ? 1 + plusOnes : 0;

  factory EventInvite.fromJson(Map<String, dynamic> json) => EventInvite(
    id: json['id'] as String,
    person: json['person'] == null
        ? null
        : PersonIdentity.fromJson(json['person'] as Map<String, dynamic>),
    invitedUserId: json['invitedUserId'] as String?,
    rsvp: RsvpResponse.fromWire(json['rsvp'] as String?),
    plusOnes: json['plusOnes'] as int? ?? 0,
    message: json['message'] as String?,
    respondedAt: json['respondedAt'] == null
        ? null
        : DateTime.parse(json['respondedAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// What a bulk invite actually did. Duplicates are collapsed rather than
/// rejected — a contact list routinely repeats someone.
@immutable
class BulkInviteResult {
  const BulkInviteResult({
    required this.created,
    required this.duplicates,
    required this.skipped,
  });

  final List<EventInvite> created;

  /// Already invited; not an error.
  final int duplicates;

  /// No usable contact at all.
  final int skipped;

  factory BulkInviteResult.fromJson(Map<String, dynamic> json) =>
      BulkInviteResult(
        created:
            (json['created'] as List<dynamic>?)
                ?.map((e) => EventInvite.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        duplicates: json['duplicates'] as int? ?? 0,
        skipped: json['skipped'] as int? ?? 0,
      );
}
