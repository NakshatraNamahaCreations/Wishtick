import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/session_controller.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../network/api_exception.dart';
import 'push_service.dart';

/// Keeps the server's device-token registry in step with who is signed in.
///
/// Registration is deliberately tied to the *session*, not to app startup: a
/// token is a delivery address, and one left registered after sign-out puts the
/// previous account's notifications on the next person's lock screen. The
/// backend upserts on the token rather than on (user, token) for the same
/// reason — see `POST /me/devices`.
///
/// Driven by listening to [sessionProvider] rather than by calls inside
/// [SessionController], so the session has no idea push exists and there is no
/// path that signs someone out without this seeing it — an expired refresh
/// token ends a session too, and it never goes through `signOut()`.
class PushRegistrar {
  PushRegistrar(this._push, this._notifications);

  final PushService _push;
  final NotificationsRepository _notifications;

  /// The token currently registered, so sign-out knows what to withdraw.
  String? _registered;
  StreamSubscription<String>? _refreshes;

  @visibleForTesting
  String? get registeredToken => _registered;

  /// Android/iOS/web, as the server's `DevicePlatform` spells them.
  static String get platform {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : 'android';
  }

  /// Called when a session begins.
  ///
  /// Every failure here is swallowed: push is a convenience, and a person who
  /// cannot receive notifications must still be able to use the app. A refused
  /// permission is not a failure at all — it is an answer.
  Future<void> onSignedIn() async {
    try {
      if (!await _push.requestPermission()) return;

      final token = await _push.token();
      if (token == null) return;
      await _register(token);

      // FCM rotates tokens on reinstall, restore, and sometimes unprompted.
      // Nothing errors when it happens — delivery just stops — so the only
      // way to notice is to listen.
      await _refreshes?.cancel();
      _refreshes = _push.onTokenRefresh().listen(_register);
    } on Exception catch (error) {
      debugPrint('Push registration failed: $error');
    }
  }

  /// Called when a session ends, however it ended.
  Future<void> onSignedOut() async {
    await _refreshes?.cancel();
    _refreshes = null;

    final token = _registered;
    _registered = null;
    if (token == null) return;

    try {
      await _notifications.unregisterDevice(token);
    } on ApiException catch (error) {
      // Best-effort, like the sign-out call it accompanies: the tokens are
      // already gone locally, and the server prunes an address FCM later
      // reports as unregistered anyway.
      debugPrint('Push unregistration failed: $error');
    }
  }

  Future<void> _register(String token) async {
    try {
      await _notifications.registerDevice(token: token, platform: platform);
      _registered = token;
    } on ApiException catch (error) {
      debugPrint('Push registration rejected: $error');
    }
  }

  void dispose() {
    unawaited(_refreshes?.cancel());
  }
}

/// Null when no push provider is installed — see [pushServiceProvider].
final pushRegistrarProvider = Provider<PushRegistrar?>((ref) {
  final push = ref.watch(pushServiceProvider);
  if (push == null) return null;

  final registrar = PushRegistrar(
    push,
    ref.watch(notificationsRepositoryProvider),
  );
  ref.onDispose(registrar.dispose);
  return registrar;
});

/// Wires [PushRegistrar] to the session for the life of the app.
///
/// A provider rather than a widget so it cannot be forgotten in one branch of
/// the tree, and `listenSelf` so it starts working the moment it is first
/// read — see [WishtickApp], which reads it once at the root.
final pushSessionSyncProvider = Provider<void>((ref) {
  ref.listen<SessionState>(sessionProvider, (previous, next) {
    final was = previous?.isAuthenticated ?? false;
    final now = next.isAuthenticated;
    if (was == now) return;

    final registrar = ref.read(pushRegistrarProvider);
    if (registrar == null) return;
    unawaited(now ? registrar.onSignedIn() : registrar.onSignedOut());
  }, fireImmediately: true);
});
