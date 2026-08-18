import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/event.dart';
import '../domain/invite_template.dart';
import '../domain/invited_event.dart';

/// Which file "Download Guest List" should produce (`4096:206`).
enum GuestListFormat {
  pdf('pdf', 'PDF', 'Best for printing and sharing'),
  xlsx('xlsx', 'Excel (.xlsx)', 'Best for editing and analytics'),
  csv('csv', 'CSV', 'Best for simple data export');

  const GuestListFormat(this.wireValue, this.label, this.blurb);

  final String wireValue;
  final String label;
  final String blurb;
}

/// A downloaded guest list, as bytes plus the name the server chose.
class GuestListDownload {
  const GuestListDownload({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final List<int> bytes;
  final String filename;
  final String contentType;
}

/// The host side of events: create, publish, invite, and the guest list.
///
/// The invitee side lives in `InviteRepository` — it is unauthenticated and
/// keyed by a token, which is a different enough contract to keep apart.
class EventsRepository {
  EventsRepository(this._api);

  final ApiClient _api;

  // ── Events ──────────────────────────────────────────────────────────────

  Future<List<WishtickEventDetail>> listMine() async {
    final json = await _api.get<List<dynamic>>('/events/mine');
    return json
        .map((e) => WishtickEventDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Events other people invited you to (`324:973`'s Invites tab).
  ///
  /// A different shape from [listMine]: a guest sees the card and their own
  /// RSVP, never the guest list or the host's editing surface.
  Future<List<InvitedEvent>> listInvited() async {
    final json = await _api.get<List<dynamic>>('/events/invited');
    return json
        .map((e) => InvitedEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WishtickEventDetail> get(String id) async {
    final json = await _api.get<Map<String, dynamic>>('/events/$id');
    return WishtickEventDetail.fromJson(json);
  }

  /// Creates a draft. Nothing is sent and no reminders are scheduled until
  /// [publish].
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
    final json = await _api.post<Map<String, dynamic>>(
      '/events',
      body: {
        'title': title,
        'type': type.wireValue,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'timezone': timezone,
        'endsAt': ?endsAt?.toUtc().toIso8601String(),
        'description': ?description,
        'venue': ?venue,
        'personName': ?personName,
        'relation': ?relation,
        'visibility': ?visibility?.wireValue,
        'coverMediaId': ?coverMediaId,
        'wishlistIds': ?wishlistIds,
        'inviteTemplate': ?inviteTemplate?.toJson(),
      },
    );
    return WishtickEventDetail.fromJson(json);
  }

  /// Moving `startsAt` reschedules every reminder — the server does that, not
  /// the client.
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

    /// Drops the host's uploaded artwork. Its own flag because the request
    /// body omits nulls, so `inviteMediaId: null` cannot say "clear it".
    bool clearInviteMedia = false,
    List<String>? wishlistIds,
    InviteTemplateChoice? inviteTemplate,
  }) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/events/$id',
      body: {
        'title': ?title,
        'type': ?type?.wireValue,
        'startsAt': ?startsAt?.toUtc().toIso8601String(),
        'endsAt': ?endsAt?.toUtc().toIso8601String(),
        'timezone': ?timezone,
        'description': ?description,
        'venue': ?venue,
        'personName': ?personName,
        'relation': ?relation,
        'visibility': ?visibility?.wireValue,
        'coverMediaId': ?coverMediaId,
        if (clearInviteMedia)
          'inviteMediaId': null
        else
          'inviteMediaId': ?inviteMediaId,
        'wishlistIds': ?wishlistIds,
        'inviteTemplate': ?inviteTemplate?.toJson(),
      },
    );
    return WishtickEventDetail.fromJson(json);
  }

  Future<WishtickEventDetail> publish(String id) async {
    final json = await _api.post<Map<String, dynamic>>('/events/$id/publish');
    return WishtickEventDetail.fromJson(json);
  }

  Future<void> remove(String id) => _api.delete<void>('/events/$id');

  // ── Invite design ───────────────────────────────────────────────────────

  /// The designs on offer, optionally narrowed to one occasion.
  ///
  /// This one endpoint answers with an object, not the bare array every other
  /// list route returns — hence the unwrap.
  Future<List<InviteTemplate>> templates({EventType? type}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/invite-templates',
      query: {'eventType': ?type?.wireValue},
    );
    return (json['templates'] as List<dynamic>? ?? const [])
        .map((e) => InviteTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Renders the card without saving it, so the designer shows what the guest
  /// will actually receive.
  ///
  /// Carries the palette and the resolved slot text as well as the image, so
  /// the designer can draw the card natively while the raster is still being
  /// generated.
  Future<InvitePreview> previewInvite(
    String eventId, {
    required InviteTemplateChoice choice,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/events/$eventId/invite/preview',
      // Wrapped: the endpoint takes an optional `inviteTemplate` and falls back
      // to the one saved on the event. A bare choice reads as "no choice".
      body: {'inviteTemplate': choice.toJson()},
    );
    return InvitePreview.fromJson(json);
  }

  // ── Guests ──────────────────────────────────────────────────────────────

  Future<List<EventInvite>> invites(String eventId) async {
    final json = await _api.get<List<dynamic>>('/events/$eventId/invites');
    return json
        .map((e) => EventInvite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Invites in bulk. Duplicates are collapsed rather than rejected — a
  /// contact list routinely repeats someone, and failing fifty invites over
  /// one repeat helps nobody.
  Future<BulkInviteResult> invite(
    String eventId, {
    required List<({String? email, String? phone, String? name})> recipients,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/events/$eventId/invites',
      body: {
        'recipients': recipients
            .map((r) => {'email': ?r.email, 'phone': ?r.phone, 'name': ?r.name})
            .toList(),
      },
    );
    return BulkInviteResult.fromJson(json);
  }

  Future<void> resend(String eventId, String inviteId) =>
      _api.post<void>('/events/$eventId/invites/$inviteId/resend');

  Future<void> revoke(String eventId, String inviteId) =>
      _api.delete<void>('/events/$eventId/invites/$inviteId');

  /// This guest's personal invite link, for sharing by hand.
  Future<String> inviteLink(String eventId, String inviteId) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/events/$eventId/invites/$inviteId/link',
    );
    return json['url'] as String? ?? '';
  }

  /// Downloads the guest list (`4096:206`).
  ///
  /// Goes through Dio directly rather than [ApiClient]: this response is a
  /// file, not the JSON envelope every other endpoint returns, so it needs
  /// `ResponseType.bytes` and its own header handling.
  Future<GuestListDownload> exportGuests(
    String eventId, {
    GuestListFormat format = GuestListFormat.pdf,
  }) async {
    final response = await _api.raw.get<List<int>>(
      '/events/$eventId/invites/export',
      queryParameters: {'format': format.wireValue},
      options: Options(responseType: ResponseType.bytes),
    );
    return GuestListDownload(
      bytes: response.data ?? const [],
      // The server names the file; falling back keeps a download from landing
      // with no extension if a proxy strips the header.
      filename:
          _filenameFrom(response.headers.value('content-disposition')) ??
          'guest-list.${format.wireValue}',
      contentType:
          response.headers.value('content-type') ?? 'application/octet-stream',
    );
  }

  String? _filenameFrom(String? disposition) {
    if (disposition == null) return null;
    final match = RegExp('filename="([^"]+)"').firstMatch(disposition);
    return match?.group(1);
  }
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(ref.watch(apiClientProvider));
});
