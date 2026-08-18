import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/app_notification.dart';
import '../domain/thank_you_note.dart';

/// The notification centre, its settings, and thank-you notes.
///
/// The three live together because they are one feature from the user's side:
/// a fulfilled gift raises a notification, and the thank-you it drafts is what
/// the notification asks them to send.
class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  // ── The centre ──────────────────────────────────────────────────────────

  Future<List<AppNotification>> list({int? limit, bool? unreadOnly}) async {
    final json = await _api.get<List<dynamic>>(
      '/notifications',
      query: {'limit': ?limit, 'unreadOnly': ?unreadOnly},
    );
    return json
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) =>
      _api.post<void>('/notifications/$id/read');

  Future<void> markAllRead() => _api.post<void>('/notifications/read-all');

  // ── Settings ────────────────────────────────────────────────────────────

  Future<NotificationPreferences> preferences() async {
    final json = await _api.get<Map<String, dynamic>>(
      '/notifications/preferences',
    );
    return NotificationPreferences.fromJson(json);
  }

  /// [disabled] is sent whole, not as a delta — the server stores the set, so
  /// a partial list would silently re-enable everything left out.
  Future<NotificationPreferences> updatePreferences({
    Set<String>? disabled,
    String? timezone,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietEndHour,
    bool? thankYouAutoSend,
  }) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/notifications/preferences',
      body: {
        'disabled': ?disabled?.toList(),
        'timezone': ?timezone,
        if (quietHoursEnabled != null ||
            quietStartHour != null ||
            quietEndHour != null)
          'quietHours': {
            'enabled': ?quietHoursEnabled,
            'startHour': ?quietStartHour,
            'endHour': ?quietEndHour,
          },
        'thankYouAutoSend': ?thankYouAutoSend,
      },
    );
    return NotificationPreferences.fromJson(json);
  }

  // ── Push devices ────────────────────────────────────────────────────────

  /// Registers this install's push token.
  ///
  /// The token belongs to the *install*, not the account: re-registering one
  /// that another account used re-points it, which is what stops one person's
  /// notifications landing on another person's lock screen.
  Future<String> registerDevice({
    required String token,
    required String platform,
    String? deviceName,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/me/devices',
      body: {'token': token, 'platform': platform, 'deviceName': ?deviceName},
    );
    return json['id'] as String;
  }

  /// What the client calls on sign-out.
  Future<void> unregisterDevice(String token) =>
      _api.delete<void>('/me/devices/$token');

  // ── Thank-you notes ─────────────────────────────────────────────────────

  Future<List<ThankYouNote>> thankYouNotes() async {
    final json = await _api.get<List<dynamic>>('/thank-you');
    return json
        .map((e) => ThankYouNote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ThankYouNote> thankYouNote(String id) async {
    final json = await _api.get<Map<String, dynamic>>('/thank-you/$id');
    return ThankYouNote.fromJson(json);
  }

  /// Edits the note before it goes out.
  ///
  /// Pass [kind] with a [mediaId] to attach a recording, or
  /// `kind: ThankYouKind.text` to drop one. Throws [ApiException] with
  /// `THANK_YOU_ALREADY_SENT` (409) once it has gone.
  Future<ThankYouNote> editThankYou(
    String id, {
    String? subject,
    String? body,
    ThankYouKind? kind,
    String? mediaId,
  }) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/thank-you/$id',
      body: {
        'subject': ?subject,
        'body': ?body,
        'kind': ?kind?.wireValue,
        'mediaId': ?mediaId,
      },
    );
    return ThankYouNote.fromJson(json);
  }

  Future<ThankYouNote> sendThankYou(String id) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/thank-you/$id/send-now',
    );
    return ThankYouNote.fromJson(json);
  }

  Future<ThankYouNote> skipThankYou(String id) async {
    final json = await _api.post<Map<String, dynamic>>('/thank-you/$id/skip');
    return ThankYouNote.fromJson(json);
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});
