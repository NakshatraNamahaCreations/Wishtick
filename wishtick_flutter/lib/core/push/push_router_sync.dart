import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/session_controller.dart';
import '../../features/notifications/presentation/notification_destination.dart';
import '../../features/notifications/presentation/notification_providers.dart';
import '../router/app_router.dart';
import '../router/pending_link.dart';
import 'local_notifications.dart';
import 'push_service.dart';

/// What the app does when a push arrives or is tapped.
///
/// Kept apart from [PushRegistrar], which owns the *address* — this owns what
/// is done with what arrives at it. Both are read once at the root of the
/// widget tree; watching them is what starts them.
///
/// Subscribed regardless of who is signed in, because [PushService.onMessageOpened]
/// replays the notification that launched a terminated app, and that replay
/// lands while the session is still being restored. Waiting for a session would
/// drop exactly the tap that mattered most.
class PushRouter {
  PushRouter(this._ref, this._push, this._local);

  final Ref _ref;
  final PushService _push;
  final LocalNotifications? _local;

  StreamSubscription<PushMessage>? _opened;
  StreamSubscription<PushMessage>? _foreground;

  Future<void> start() async {
    await _local?.start(_go);
    _opened = _push.onMessageOpened().listen(_onOpened);
    _foreground = _push.onForegroundMessage().listen(_onForeground);
  }

  Future<void> dispose() async {
    await _opened?.cancel();
    await _foreground?.cancel();
  }

  /// A tapped notification, from the tray or from one this app drew.
  void _onOpened(PushMessage message) {
    final destination = destinationFor(message.type, message.refId ?? '');
    if (destination == null) return;
    _go(destination);
  }

  /// A notification that arrived while the app was open.
  ///
  /// Two jobs, and the first is the one that must not be skipped: the bell's
  /// badge is derived from the notification list, so without invalidating it
  /// the count stays stale until the reader happens to pull to refresh.
  void _onForeground(PushMessage message) {
    _ref.invalidate(notificationsProvider);
    unawaited(
      _local?.show(
        message,
        destination: destinationFor(message.type, message.refId ?? ''),
      ),
    );
  }

  /// Navigates, or remembers where to go if there is nobody to navigate.
  ///
  /// A tap can arrive before the session resolves — a cold launch from the
  /// lock screen is exactly that — and pushing then would land on a route the
  /// redirect immediately bounces back to `/welcome`. [PendingDeepLink] is the
  /// mechanism the share links already use for this, and the router's redirect
  /// spends it once the user is through sign-in.
  void _go(String destination) {
    if (_ref.read(sessionProvider).isAuthenticated) {
      _ref.read(pushNavigatorProvider)(destination);
    } else {
      _ref.read(pendingDeepLinkProvider).remember(destination);
    }
  }
}

/// How a routed push actually navigates.
///
/// A seam rather than a direct `routerProvider` call: building the real
/// GoRouter reads the session and the whole route table, which is a great deal
/// of machinery to stand up for a test whose question is only *where were we
/// sent*.
final pushNavigatorProvider = Provider<void Function(String)>(
  (ref) =>
      (destination) =>
          unawaited(ref.read(routerProvider).push<void>(destination)),
);

/// Started once, at the root, for the life of the app.
///
/// Null when this build has no push service — a checkout with no Firebase
/// config, or any widget test — in which case there is nothing to subscribe to
/// and this does nothing.
final pushRouterSyncProvider = Provider<void>((ref) {
  final push = ref.watch(pushServiceProvider);
  if (push == null) return;

  final router = PushRouter(ref, push, ref.watch(localNotificationsProvider));
  unawaited(router.start());
  ref.onDispose(() => unawaited(router.dispose()));
});
