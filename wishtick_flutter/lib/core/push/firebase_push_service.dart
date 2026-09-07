import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_service.dart';

/// Handles a notification that arrives while the app is terminated or
/// backgrounded.
///
/// Top-level and `@pragma('vm:entry-point')` because Android runs it in a
/// *separate* isolate with its own memory: nothing from the running app is
/// reachable here, and the function has to survive tree-shaking to be found by
/// name. It deliberately does nothing — the system already draws the
/// notification, and the app routes on the tap, which arrives through
/// [PushService.onMessageOpened] in the normal isolate.
///
/// Registered anyway: without a handler Android logs a warning on every
/// background message, and having the entry point in place is what makes any
/// future background work (a badge count, a cache warm) a one-line change
/// rather than a re-plumbing.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// [PushService] over Firebase Cloud Messaging.
///
/// Thin on purpose. Everything policy-shaped — when to register, what to do
/// with a tap — lives in [PushRegistrar] and the router, so this file holds
/// only the parts that genuinely need the plugin.
class FirebasePushService implements PushService {
  FirebasePushService([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    final status = settings.authorizationStatus;
    // `provisional` is iOS's quiet grant — notifications are delivered
    // straight to the notification centre without a prompt. They arrive, so it
    // counts as permission.
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    try {
      return await _messaging.getToken();
    } on Exception catch (error) {
      // No network, no Play Services, a misconfigured project: all of them
      // mean "no address today", and none of them should stop the app from
      // starting.
      debugPrint('FCM token unavailable: $error');
      return null;
    }
  }

  @override
  Stream<String> onTokenRefresh() => _messaging.onTokenRefresh;

  /// The `data` block for routing, plus the `notification` block for the text.
  ///
  /// The text matters only in the foreground, where the app draws the
  /// notification itself, but reading it here keeps every message the same
  /// shape whichever stream it arrives on.
  static PushMessage _toMessage(RemoteMessage m) => PushMessage.fromData(
    m.data,
    title: m.notification?.title,
    body: m.notification?.body,
  );

  @override
  Stream<PushMessage> onForegroundMessage() =>
      FirebaseMessaging.onMessage.map(_toMessage);

  @override
  Stream<PushMessage> onMessageOpened() async* {
    // The notification that launched a terminated app is not on the stream —
    // it happened before anything subscribed — so it is replayed first.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) yield _toMessage(initial);

    yield* FirebaseMessaging.onMessageOpenedApp.map(_toMessage);
  }
}
