import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/domain/event.dart';
import 'package:wishtick_flutter/features/events/domain/invite_template.dart';
import 'package:wishtick_flutter/features/events/domain/invited_event.dart';
import 'package:wishtick_flutter/features/wishmates/domain/wishmate.dart';

WishtickEventDetail buildEvent({
  String id = 'evt_1',
  String title = "Siya's 24th",
  EventType type = EventType.birthday,
  EventStatus status = EventStatus.draft,
  InviteTemplateChoice? inviteTemplate,
  String? inviteMediaUrl,
}) => WishtickEventDetail(
  id: id,
  title: title,
  type: type,
  startsAt: DateTime.utc(2026, 7, 19, 14, 30),
  timezone: 'Asia/Kolkata',
  visibility: EventVisibility.private,
  status: status,
  wishlistIds: const [],
  createdAt: DateTime.utc(2026, 7, 1),
  venue: 'Mysore Socials',
  personName: 'Siya',
  relation: 'friend',
  inviteTemplate: inviteTemplate,
  inviteMediaUrl: inviteMediaUrl,
  share: const EventShare(
    slug: 'siya-24th',
    url: 'https://wt.test/e/siya-24th',
  ),
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

class FakeEventsRepository implements EventsRepository {
  FakeEventsRepository({
    List<EventInvite>? invites,
    WishtickEventDetail? event,
    List<WishtickEventDetail>? hosted,
  }) : guests = invites ?? [],
       event = event ?? buildEvent(),
       hosted = hosted ?? [event ?? buildEvent()];

  WishtickEventDetail event;

  /// What "My Events" lists. Separate from [event], which is the single
  /// capsule the detail screens read.
  List<WishtickEventDetail> hosted;

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

  /// Empty by default: these tests exercise the host's side, and inventing an
  /// invitation would put a guest rail in front of screens that have none.
  @override
  Future<List<InvitedEvent>> listInvited() async => const [];

  @override
  Future<WishtickEventDetail> get(String id) async => event;

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
    EventVisibility? visibility,
    String? coverMediaId,
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
    });
    return event;
  }

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
      'templateId': inviteTemplate?.templateId,
      'colorVariant': inviteTemplate?.colorVariant,
    });
    return event;
  }

  @override
  Future<WishtickEventDetail> publish(String id) async {
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
