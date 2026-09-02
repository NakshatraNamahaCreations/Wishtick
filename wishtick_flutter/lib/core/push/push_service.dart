import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A push notification as the app cares about it.
///
/// Only the two fields the backend actually routes on. FCM carries a title and
/// body too, but the system draws those itself when the app is in the
/// background — what the app needs is *where to go* when the notification is
/// tapped.
@immutable
class PushMessage {
  const PushMessage({required this.type, this.refId});

  /// One of `NotificationType` on the server — `gift_reserved`,
  /// `event_reminder`, and so on.
  final String type;

  /// The id of whatever the notification is about, when it is about one thing.
  final String? refId;

  /// FCM data values are always strings, so nothing here is parsed further.
  factory PushMessage.fromData(Map<String, dynamic> data) => PushMessage(
    type: data['type']?.toString() ?? '',
    refId: data['refId']?.toString(),
  );

  @override
  bool operator ==(Object other) =>
      other is PushMessage && other.type == type && other.refId == refId;

  @override
  int get hashCode => Object.hash(type, refId);

  @override
  String toString() => 'PushMessage($type, $refId)';
}

/// What the app needs from a push provider.
///
/// A port rather than calling `FirebaseMessaging` directly, for the same
/// reason the backend has one: it keeps Firebase out of the widget tree's
/// dependencies, so the registration logic — which is where the bugs live —
/// can be tested without a platform channel. [FirebasePushService] is the real
/// one; tests supply their own.
abstract class PushService {
  /// Asks the OS for permission, and reports whether it was granted.
  ///
  /// Android 12 and below grant it implicitly; 13+ shows a prompt, and iOS
  /// always does. A refusal is a normal outcome, not an error.
  Future<bool> requestPermission();

  /// This install's address, or null when permission was refused or the
  /// provider could not reach its servers.
  Future<String?> token();

  /// Fires when FCM rotates the token, which it does on reinstall, restore,
  /// and occasionally on its own. Without re-registering, delivery silently
  /// stops — nothing errors, the pushes just go to an address that no longer
  /// exists.
  Stream<String> onTokenRefresh();

  /// Notifications that arrive while the app is open, where the OS shows
  /// nothing by default.
  Stream<PushMessage> onForegroundMessage();

  /// A notification the user tapped to open or resume the app. Replays the one
  /// that launched a terminated app, which would otherwise be missed — the
  /// stream is subscribed to long after the tap happened.
  Stream<PushMessage> onMessageOpened();
}

/// The installed provider, or null when there is none.
///
/// Nullable rather than throwing: "this build has no push" is a legitimate
/// state — a device without Play Services, a checkout with no
/// `google-services.json`, every widget test — and it must not be able to take
/// the app down at the moment someone signs in. `main()` overrides this with
/// [FirebasePushService] once Firebase has actually started; tests supply
/// their own.
final pushServiceProvider = Provider<PushService?>((ref) => null);
