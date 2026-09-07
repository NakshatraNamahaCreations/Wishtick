import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/push/local_notifications.dart';
import 'package:wishtick_flutter/core/push/push_router_sync.dart';
import 'package:wishtick_flutter/core/push/push_service.dart';
import 'package:wishtick_flutter/core/router/app_routes.dart';
import 'package:wishtick_flutter/core/router/pending_link.dart';
import 'package:wishtick_flutter/features/auth/presentation/session_controller.dart';
import 'package:wishtick_flutter/features/notifications/presentation/notification_providers.dart';

/// What happens to a push once it arrives.
///
/// Until this existed the token registered, the OS drew the notification, and
/// tapping it opened the app on whatever screen it was already on — the whole
/// point of the notification lost at the last step.
class _FakePush implements PushService {
  final opened = StreamController<PushMessage>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();

  @override
  Stream<PushMessage> onMessageOpened() => opened.stream;

  @override
  Stream<PushMessage> onForegroundMessage() => foreground.stream;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<String?> token() async => 'tok_1';

  @override
  Stream<String> onTokenRefresh() => const Stream.empty();
}

class _FakeLocal implements LocalNotifications {
  final shown = <(PushMessage, String?)>[];
  ValueChanged<String>? tapped;

  @override
  Future<void> start(ValueChanged<String> onOpened) async => tapped = onOpened;

  @override
  Future<void> show(PushMessage message, {String? destination}) async =>
      shown.add((message, destination));
}

/// Records where the app was told to go, without a widget tree or a real
/// router — the decision is what these tests are about, not the navigation.
class _Routes {
  final pushed = <String>[];
}

void main() {
  late _FakePush push;
  late _FakeLocal local;
  late _Routes routes;

  /// A container with the push plumbing faked and navigation recorded.
  ///
  /// `routerProvider` builds a real GoRouter that reads the session and the
  /// whole route table, so it is overridden with a recorder rather than
  /// exercised.
  ProviderContainer build({required bool signedIn}) {
    push = _FakePush();
    local = _FakeLocal();
    routes = _Routes();

    final container = ProviderContainer(
      overrides: [
        pushServiceProvider.overrideWithValue(push),
        localNotificationsProvider.overrideWithValue(local),
        pushNavigatorProvider.overrideWithValue(routes.pushed.add),
        sessionProvider.overrideWith(() => _FakeSession(signedIn: signedIn)),
      ],
    );
    addTearDown(container.dispose);
    container.read(pushRouterSyncProvider);
    return container;
  }

  test('tapping a notification opens what it is about', () async {
    build(signedIn: true);
    await pumpEventQueue();

    push.opened.add(const PushMessage(type: 'memory_unlocked', refId: 'm_1'));
    await pumpEventQueue();

    expect(routes.pushed, [AppRoutes.memory('m_1')]);
  });

  // A cold launch from the lock screen arrives here before the session has
  // resolved. Navigating then lands on a route the redirect bounces straight
  // back to /welcome, losing the tap that mattered most.
  test('a tap while signed out is remembered for after sign-in', () async {
    final container = build(signedIn: false);
    await pumpEventQueue();

    push.opened.add(const PushMessage(type: 'memory_unlocked', refId: 'm_1'));
    await pumpEventQueue();

    expect(routes.pushed, isEmpty);
    expect(
      container.read(pendingDeepLinkProvider).take(),
      AppRoutes.memory('m_1'),
    );
  });

  test('a type this build cannot route goes nowhere at all', () async {
    final container = build(signedIn: true);
    await pumpEventQueue();

    push.opened.add(const PushMessage(type: 'invented_later', refId: 'x_1'));
    await pumpEventQueue();

    expect(routes.pushed, isEmpty);
    expect(container.read(pendingDeepLinkProvider).take(), isNull);
  });

  // Android hands a foreground message to the app instead of the tray, so
  // without drawing it here a push that lands mid-session is invisible.
  test('a notification arriving while the app is open is drawn', () async {
    build(signedIn: true);
    await pumpEventQueue();

    push.foreground.add(
      const PushMessage(
        type: 'group_gift_funded',
        refId: 'gg_1',
        title: 'Fully funded 🎉',
        body: "Siya's birthday gift reached its goal.",
      ),
    );
    await pumpEventQueue();

    expect(local.shown, hasLength(1));
    expect(local.shown.single.$1.title, 'Fully funded 🎉');
    // Carries where to go, so tapping the one the app drew behaves like
    // tapping one the system drew.
    expect(local.shown.single.$2, AppRoutes.groupGift('gg_1'));
  });

  // The bell's badge counts the notification list. Without invalidating it the
  // count stays wrong until the reader happens to pull to refresh.
  test('a foreground notification refreshes the unread badge', () async {
    final container = build(signedIn: true);
    // Seed the list so there is something to invalidate.
    container.listen(notificationsProvider, (_, _) {});
    await pumpEventQueue();
    final before = container.read(notificationsProvider);

    push.foreground.add(
      const PushMessage(type: 'group_gift_funded', refId: 'gg_1', title: 'Hi'),
    );
    await pumpEventQueue();

    expect(identical(container.read(notificationsProvider), before), isFalse);
  });

  test('tapping one the app drew navigates the same way', () async {
    build(signedIn: true);
    await pumpEventQueue();

    // The plugin hands back the payload the notification was drawn with.
    local.tapped!(AppRoutes.groupGift('gg_9'));
    await pumpEventQueue();

    expect(routes.pushed, [AppRoutes.groupGift('gg_9')]);
  });

  test('a build with no push service subscribes to nothing', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Reading it must not throw, and must not reach for a service that is not
    // there — every widget test runs in exactly this state.
    expect(() => container.read(pushRouterSyncProvider), returnsNormally);
  });
}

/// A session pinned to one answer. The real controller restores from storage
/// and calls the network on build.
class _FakeSession extends SessionController {
  _FakeSession({required this.signedIn});

  final bool signedIn;

  @override
  SessionState build() => SessionState(
    status: signedIn
        ? SessionStatus.authenticated
        : SessionStatus.unauthenticated,
  );
}
