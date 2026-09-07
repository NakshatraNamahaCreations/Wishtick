import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_service.dart';

/// The one channel every Wishtick notification lands on.
///
/// Named in `AndroidManifest.xml` as `default_notification_channel_id` as well,
/// so a notification the system draws in the background and one this file draws
/// in the foreground are the same channel — one entry in the OS settings, one
/// switch for the reader to turn the lot off. Two ids would give them two, and
/// muting one would look like muting both.
const kNotificationChannelId = 'wishtick_default';
const _channelName = 'Wishtick';
const _channelDescription =
    'Gifts, group gifts, events and reminders from Wishtick.';

/// Draws a notification the app was handed rather than the system.
///
/// FCM only delivers to the tray while the app is backgrounded or dead; a
/// message arriving while someone is *using* the app goes to
/// [PushService.onForegroundMessage] and the OS draws nothing at all. Without
/// this, a push that lands mid-session is invisible.
abstract class LocalNotifications {
  /// Creates the channel and wires the tap callback. Safe to call twice.
  Future<void> start(ValueChanged<String> onOpened);

  /// Draws [message], carrying [destination] as the payload its tap returns.
  Future<void> show(PushMessage message, {String? destination});
}

class FlutterLocalNotifications implements LocalNotifications {
  FlutterLocalNotifications([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _started = false;

  /// Ids only have to be unique among the notifications currently on screen.
  /// Monotonic rather than hashed from the message: two contributions to the
  /// same group gift are two things that happened, and hashing would let the
  /// second quietly replace the first.
  int _nextId = 0;

  @override
  Future<void> start(ValueChanged<String> onOpened) async {
    if (_started) return;
    _started = true;

    await _plugin.initialize(
      const InitializationSettings(
        // The small icon Android draws in the status bar. A launcher icon
        // cannot stand in: Android renders this one as a silhouette, so a
        // full-colour asset comes out a white square.
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final destination = response.payload;
        if (destination != null && destination.isNotEmpty) {
          onOpened(destination);
        }
      },
    );

    // Created up front rather than on the first notification: the channel is
    // what the manifest's default points at, so it has to exist before a
    // *background* message arrives too — and that one never reaches this code.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            kNotificationChannelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
  }

  @override
  Future<void> show(PushMessage message, {String? destination}) async {
    final title = message.title;
    // A data-only message has nothing to draw. Silently skipping is right:
    // the foreground handler still refreshed the bell, which is the part that
    // matters, and an empty notification would be worse than none.
    if (title == null || title.isEmpty) return;

    await _plugin.show(
      _nextId++,
      title,
      message.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kNotificationChannelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: destination,
    );
  }
}

/// The installed drawer, or null when there is none.
///
/// Nullable for the same reason [pushServiceProvider] is: a build without push
/// and every widget test must work without one. `main()` overrides it alongside
/// the push service.
final localNotificationsProvider = Provider<LocalNotifications?>((ref) => null);
