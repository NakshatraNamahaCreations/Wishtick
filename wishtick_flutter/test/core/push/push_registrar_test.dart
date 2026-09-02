import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/push/push_registrar.dart';
import 'package:wishtick_flutter/core/push/push_service.dart';
import 'package:wishtick_flutter/features/notifications/data/notifications_repository.dart';

/// Keeping the server's device-token registry in step with the session.
///
/// The failures here are not cosmetic. A token is a delivery address: one left
/// registered after sign-out puts the previous account's notifications on the
/// next person's lock screen, and one never re-registered after FCM rotates it
/// stops delivery with nothing reported anywhere.
class _FakePush implements PushService {
  bool granted = true;
  String? initialToken = 'tok_1';
  int permissionAsks = 0;

  final refreshes = StreamController<String>.broadcast();

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return granted;
  }

  @override
  Future<String?> token() async => initialToken;

  @override
  Stream<String> onTokenRefresh() => refreshes.stream;

  @override
  Stream<PushMessage> onForegroundMessage() => const Stream.empty();

  @override
  Stream<PushMessage> onMessageOpened() => const Stream.empty();
}

/// Local rather than the shared `FakeNotificationsRepository`: that one is
/// used by several screen tests and records nothing, and these assertions are
/// entirely about *which calls were made*.
class _FakeApi implements NotificationsRepository {
  final registered = <(String token, String platform)>[];
  final unregistered = <String>[];
  bool failRegister = false;
  bool failUnregister = false;

  static const _failure = ApiException(
    code: 'SERVER_ERROR',
    message: 'nope',
    statusCode: 500,
  );

  @override
  Future<String> registerDevice({
    required String token,
    required String platform,
    String? deviceName,
  }) async {
    if (failRegister) throw _failure;
    registered.add((token, platform));
    return 'device_1';
  }

  @override
  Future<void> unregisterDevice(String token) async {
    if (failUnregister) throw _failure;
    unregistered.add(token);
  }

  /// Nothing else on the repository is reachable from the registrar, and a
  /// call that appears here later should fail loudly rather than return null.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not used by push');
}

void main() {
  late _FakePush push;
  late _FakeApi api;
  late PushRegistrar registrar;

  setUp(() {
    push = _FakePush();
    api = _FakeApi();
    registrar = PushRegistrar(push, api);
  });

  tearDown(() {
    registrar.dispose();
    push.refreshes.close();
  });

  test('signing in asks permission and registers this install', () async {
    await registrar.onSignedIn();

    expect(push.permissionAsks, 1);
    expect(api.registered, [('tok_1', PushRegistrar.platform)]);
  });

  test('a refused permission registers nothing, and is not an error', () async {
    push.granted = false;

    await registrar.onSignedIn();

    // Declining notifications is an answer, not a failure — the app carries on.
    expect(api.registered, isEmpty);
    expect(registrar.registeredToken, isNull);
  });

  test('no token available registers nothing', () async {
    // What a device with no Play Services, or no network, reports.
    push.initialToken = null;

    await registrar.onSignedIn();

    expect(api.registered, isEmpty);
  });

  test(
    'a rotated token is re-registered, because nothing else notices',
    () async {
      await registrar.onSignedIn();

      push.refreshes.add('tok_2');
      await pumpEventQueue();

      expect(api.registered, [
        ('tok_1', PushRegistrar.platform),
        ('tok_2', PushRegistrar.platform),
      ]);
      // And sign-out must withdraw the *current* address, not the first one.
      expect(registrar.registeredToken, 'tok_2');
    },
  );

  test('signing out withdraws the token', () async {
    await registrar.onSignedIn();
    await registrar.onSignedOut();

    expect(api.unregistered, ['tok_1']);
    expect(registrar.registeredToken, isNull);
  });

  test(
    'signing out stops listening, so a later rotation registers nothing',
    () async {
      await registrar.onSignedIn();
      await registrar.onSignedOut();

      push.refreshes.add('tok_3');
      await pumpEventQueue();

      // A subscription outliving the session is how a signed-out install ends up
      // back in the registry, receiving the next user's notifications.
      expect(api.registered, hasLength(1));
    },
  );

  test('signing out with nothing registered calls nothing', () async {
    push.granted = false;
    await registrar.onSignedIn();

    await registrar.onSignedOut();

    expect(api.unregistered, isEmpty);
  });

  test('a rejected registration leaves no token to withdraw', () async {
    api.failRegister = true;

    await registrar.onSignedIn();
    await registrar.onSignedOut();

    // Recording a token the server refused would send a DELETE for an address
    // it never stored.
    expect(registrar.registeredToken, isNull);
    expect(api.unregistered, isEmpty);
  });

  test(
    'a failed unregister does not throw — sign-out must not be blocked',
    () async {
      api.failUnregister = true;
      await registrar.onSignedIn();

      await expectLater(registrar.onSignedOut(), completes);
      expect(registrar.registeredToken, isNull);
    },
  );

  test('platform is spelled the way the server enumerates it', () {
    // DevicePlatform on the backend is android | ios | web. Any other spelling
    // is a 400 at registration time, on a call nothing surfaces.
    expect(PushRegistrar.platform, anyOf('android', 'ios', 'web'));
  });

  test('signing in twice does not leave two refresh listeners', () async {
    await registrar.onSignedIn();
    await registrar.onSignedIn();

    api.registered.clear();
    push.refreshes.add('tok_9');
    await pumpEventQueue();

    // Two live subscriptions would register the same rotated token twice.
    expect(api.registered, hasLength(1));
  });
}
