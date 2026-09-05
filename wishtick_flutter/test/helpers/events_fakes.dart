import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/domain/event.dart';
import 'package:wishtick_flutter/features/events/domain/event_wishlist_request.dart';
import 'package:wishtick_flutter/features/events/domain/invite_template.dart';
import 'package:wishtick_flutter/features/events/domain/invited_event.dart';
// The guest-side event uses the public invite's own enums, which are distinct
// types from `event.dart`'s of the same names.
import 'package:wishtick_flutter/features/events/domain/public_invite.dart'
    as guest;
import 'package:wishtick_flutter/features/wishmates/domain/wishmate.dart';

/// An event somebody else invited you to, as the Invites tab lists it.
InvitedEvent buildInvitedEvent({
  String id = 'evt_9',
  String title = "Rohan's Housewarming",
  String? inviteMediaUrl,
  String? coverUrl,
  String? hostName = 'Rohan',
  guest.RsvpResponse myRsvp = guest.RsvpResponse.pending,
  String? inviteToken = 'tok_9',
}) => InvitedEvent(
  id: id,
  title: title,
  type: guest.EventType.generic,
  startsAt: DateTime.now().add(const Duration(days: 3)),
  timezone: 'Asia/Kolkata',
  coverUrl: coverUrl,
  inviteMediaUrl: inviteMediaUrl,
  hostName: hostName,
  myRsvp: myRsvp,
  inviteToken: inviteToken,
);

WishtickEventDetail buildEvent({
  String id = 'evt_1',
  String title = "Siya's 24th",
  EventType type = EventType.birthday,
  EventStatus status = EventStatus.draft,
  InviteTemplateChoice? inviteTemplate,
  String? inviteMediaUrl,
  String? description,
  String? venue = 'Mysore Socials',
  List<String> wishlistIds = const [],
  RsvpCounts? rsvpCounts,
  bool forSelf = false,
  // False for a guest's view: the link is host-only, and its absence is what
  // tells a screen it cannot manage the event.
  bool shareable = true,
  // Private is the server's default, and the one whose link admits nobody.
  EventVisibility visibility = EventVisibility.private,
  int pendingWishlistCount = 0,
}) => WishtickEventDetail(
  id: id,
  title: title,
  type: type,
  startsAt: DateTime.utc(2026, 7, 19, 14, 30),
  timezone: 'Asia/Kolkata',
  visibility: visibility,
  status: status,
  wishlistIds: wishlistIds,
  createdAt: DateTime.utc(2026, 7, 1),
  description: description,
  rsvpCounts: rsvpCounts,
  venue: venue,
  personName: 'Siya',
  relation: 'friend',
  inviteTemplate: inviteTemplate,
  inviteMediaUrl: inviteMediaUrl,
  forSelf: forSelf,
  pendingWishlistCount: pendingWishlistCount,
  share: shareable
      ? const EventShare(slug: 'siya-24th', url: 'https://wt.test/e/siya-24th')
      : null,
);

EventInvite buildInviteRow({
  required String id,
  required String name,
  RsvpResponse rsvp = RsvpResponse.pending,
  int plusOnes = 0,
  String? username = 'guest',
  DateTime? respondedAt,
}) => EventInvite(
  id: id,
  person: PersonIdentity(
    userId: 'u-$id',
    username: username,
    displayName: name,
    photoUrl: null,
    online: false,
    lastSeenAt: null,
  ),
  invitedUserId: 'u-$id',
  rsvp: rsvp,
  plusOnes: plusOnes,
  createdAt: DateTime.utc(2026, 7, 14, 4, 30),
  respondedAt: respondedAt,
);

InviteTemplate buildTemplate({
  required String id,
  required String name,
  List<EventType> eventTypes = const [EventType.birthday],
}) => InviteTemplate(
  id: id,
  name: name,
  description: name,
  eventTypes: eventTypes,
  slots: const [],
  variants: const [
    TemplateColorVariant(
      key: 'plum',
      label: 'Plum',
      background: '#3C2415',
      accent: '#E8C39E',
      text: '#FFFFFF',
      muted: '#D9CFC5',
    ),
  ],
);

EventWishlistRequest buildWishlistOffer({
  String id = 'req_1',
  String eventId = 'ev_1',
  String wishlistId = 'wl_1',
  String wishlistTitle = 'My birthday list',
  int itemCount = 4,
  String requestedByName = 'Siya',
  EventWishlistRequestStatus status = EventWishlistRequestStatus.pending,
}) => EventWishlistRequest(
  id: id,
  eventId: eventId,
  wishlistId: wishlistId,
  wishlistTitle: wishlistTitle,
  itemCount: itemCount,
  requestedById: 'u_1',
  requestedByName: requestedByName,
  status: status,
  createdAt: DateTime(2026, 8, 1),
);

class FakeEventsRepository implements EventsRepository {
  FakeEventsRepository({
    List<EventInvite>? invites,
    WishtickEventDetail? event,
    List<WishtickEventDetail>? hosted,
    List<InvitedEvent>? invited,
  }) : guests = invites ?? [],
       event = event ?? buildEvent(),
       hosted = hosted ?? [event ?? buildEvent()],
       invited = invited ?? [];

  WishtickEventDetail event;

  /// What "My Events" lists. Separate from [event], which is the single
  /// capsule the detail screens read.
  List<WishtickEventDetail> hosted;

  /// What the Invites tab lists — other people's events.
  List<InvitedEvent> invited;

  /// Not named `invites` — that collides with `EventsRepository.invites()`.
  List<EventInvite> guests;
  List<InviteTemplate> catalogue = [
    buildTemplate(id: 'tpl_1', name: 'Golden Bloom'),
    buildTemplate(
      id: 'tpl_2',
      name: 'Evergreen',
      eventTypes: const [EventType.anniversary],
    ),
  ];

  Object? failure;

  final createCalls = <Map<String, Object?>>[];
  final updateCalls = <Map<String, Object?>>[];
  final revoked = <String>[];
  final publishCalls = <String>[];
  final exportCalls = <GuestListFormat>[];

  void _maybeThrow() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<List<WishtickEventDetail>> listMine() async {
    _maybeThrow();
    return hosted;
  }

  /// Empty by default: most tests exercise the host's side, and inventing an
  /// invitation would put a guest rail in front of screens that have none.
  @override
  Future<List<InvitedEvent>> listInvited() async {
    _maybeThrow();
    return invited;
  }

  @override
  Future<WishtickEventDetail> get(String id) async {
    _maybeThrow();
    return event;
  }

  @override
  Future<WishtickEventDetail> create({
    required String title,
    required EventType type,
    required DateTime startsAt,
    required String timezone,
    DateTime? endsAt,
    String? description,
    String? venue,
    String? personName,
    String? relation,
    bool? forSelf,
    EventVisibility? visibility,
    String? coverMediaId,
    String? inviteMediaId,
    List<String>? wishlistIds,
    InviteTemplateChoice? inviteTemplate,
  }) async {
    _maybeThrow();
    createCalls.add({
      'title': title,
      'type': type,
      'startsAt': startsAt,
      'timezone': timezone,
      'description': description,
      'venue': venue,
      'personName': personName,
      'relation': relation,
      'forSelf': forSelf,
      'inviteMediaId': inviteMediaId,
      'wishlistIds': wishlistIds,
      'visibility': visibility,
    });
    return event;
  }

  /// Thrown by [publish] alone, so a test can fail the last step of a create
  /// and watch the retry pick up from there rather than start over.
  Object? publishFailure;

  @override
  Future<WishtickEventDetail> update(
    String id, {
    String? title,
    EventType? type,
    DateTime? startsAt,
    DateTime? endsAt,
    String? timezone,
    String? description,
    String? venue,
    String? personName,
    String? relation,
    bool? forSelf,
    EventVisibility? visibility,
    String? coverMediaId,
    String? inviteMediaId,
    bool clearInviteMedia = false,
    List<String>? wishlistIds,
    InviteTemplateChoice? inviteTemplate,
  }) async {
    _maybeThrow();
    updateCalls.add({
      'id': id,
      'inviteMediaId': inviteMediaId,
      'clearInviteMedia': clearInviteMedia,
      'forSelf': forSelf,
      'wishlistIds': wishlistIds,
      'templateId': inviteTemplate?.templateId,
      'colorVariant': inviteTemplate?.colorVariant,
    });
    return event;
  }

  @override
  Future<WishtickEventDetail> publish(String id) async {
    final f = publishFailure;
    if (f != null) throw f;
    publishCalls.add(id);
    return event;
  }

  @override
  Future<void> remove(String id) async {}

  @override
  Future<List<InviteTemplate>> templates({EventType? type}) async => catalogue;

  @override
  Future<InvitePreview> previewInvite(
    String eventId, {
    required InviteTemplateChoice choice,
  }) async => InvitePreview(
    templateId: choice.templateId,
    colorVariant: choice.colorVariant,
    palette: catalogue.first.variants.first,
    resolved: const InviteCardContent(
      headline: 'Siya',
      dateLine: 'SUNDAY 19 JULY AT 8PM',
      subtitle: '24th Birthday',
      venue: 'Mysore Socials',
    ),
  );

  @override
  Future<List<EventInvite>> invites(String eventId) async => guests;

  /// The user ids [inviteWishmates] was handed, so a test can assert who was
  /// invited rather than only that something was.
  final invitedUserIds = <String>[];

  /// What the host's queue answers with.
  List<EventWishlistRequest> wishlistOffers = const [];

  /// Every offer sent, as (eventId, wishlistId).
  final offeredWishlists = <(String, String)>[];

  /// Every answer, as (requestId, approved).
  final answeredWishlists = <(String, bool)>[];

  /// Every removal, by request id.
  final removedWishlists = <String>[];

  @override
  Future<EventWishlistRequest> offerWishlist(
    String eventId,
    String wishlistId,
  ) async {
    _maybeThrow();
    offeredWishlists.add((eventId, wishlistId));
    return buildWishlistOffer(wishlistId: wishlistId);
  }

  @override
  Future<List<EventWishlistRequest>> wishlistRequests(String eventId) async {
    _maybeThrow();
    return wishlistOffers;
  }

  @override
  Future<List<EventWishlistRequest>> myWishlistRequests() async {
    _maybeThrow();
    return wishlistOffers;
  }

  @override
  Future<EventWishlistRequest> respondToWishlistRequest(
    String eventId,
    String requestId, {
    required bool approve,
  }) async {
    _maybeThrow();
    answeredWishlists.add((requestId, approve));
    return buildWishlistOffer(id: requestId);
  }

  @override
  Future<EventWishlistRequest> removeWishlistRequest(
    String eventId,
    String requestId,
  ) async {
    _maybeThrow();
    removedWishlists.add(requestId);
    return buildWishlistOffer(id: requestId);
  }

  @override
  Future<BulkInviteResult> inviteWishmates(
    String eventId,
    List<String> userIds,
  ) async {
    _maybeThrow();
    invitedUserIds.addAll(userIds);
    return const BulkInviteResult(created: [], duplicates: 0, skipped: 0);
  }

  /// Ids handed to the last bulk delete, in the order they were sent.
  final deletedIds = <String>[];

  @override
  Future<int> deleteMany(List<String> ids) async {
    _maybeThrow();
    deletedIds.addAll(ids);
    hosted = hosted.where((e) => !ids.contains(e.id)).toList();
    return ids.length;
  }

  /// Every invite-by-phone, as (eventId, numbers) — so a test can assert that
  /// what left the app was E.164 numbers rather than whatever the address
  /// book had written down.
  final phoneInviteCalls = <(String, List<String>)>[];

  @override
  Future<BulkInviteResult> inviteByPhone(
    String eventId,
    List<String> phones,
  ) async {
    _maybeThrow();
    phoneInviteCalls.add((eventId, phones));
    return BulkInviteResult(
      created: [
        for (final _ in phones)
          buildInviteRow(id: 'i_${phoneInviteCalls.length}', name: 'Invited'),
      ],
      duplicates: 0,
      skipped: 0,
    );
  }

  @override
  Future<void> revoke(String eventId, String inviteId) async {
    _maybeThrow();
    revoked.add(inviteId);
    guests = guests.where((i) => i.id != inviteId).toList();
  }

  @override
  Future<String> inviteLink(String eventId, String inviteId) async =>
      'https://wt.test/i/tok';

  @override
  Future<GuestListDownload> exportGuests(
    String eventId, {
    GuestListFormat format = GuestListFormat.pdf,
  }) async {
    exportCalls.add(format);
    return GuestListDownload(
      bytes: const [1, 2, 3],
      filename: 'guest-list.${format.wireValue}',
      contentType: 'application/octet-stream',
    );
  }
}
