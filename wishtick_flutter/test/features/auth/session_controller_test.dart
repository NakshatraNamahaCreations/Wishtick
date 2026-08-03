import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_client.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/features/auth/data/auth_repository.dart';
import 'package:wishtick_flutter/features/auth/presentation/session_controller.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/onboarding_fakes.dart';

void main() {
  ({
    ProviderContainer container,
    FakeTokenStorage tokens,
    FakeAuthRepository auth,
  })
  build({String? refreshToken, ApiException? meFailure}) {
    final tokens = FakeTokenStorage(refreshToken: refreshToken);
    final auth = FakeAuthRepository(meFailure: meFailure);
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(auth),
        // Without this the onboarding check reaches the real network.
        onboardingRepositoryProvider.overrideWithValue(
          FakeOnboardingRepository(completed: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, tokens: tokens, auth: auth);
  }

  test('starts in the unknown state', () {
    final t = build();
    expect(t.container.read(sessionProvider).status, SessionStatus.unknown);
    expect(t.container.read(sessionProvider).isResolved, isFalse);
  });

  group('restore', () {
    test('signs out when no refresh token is stored', () async {
      final t = build();

      await t.container.read(sessionProvider.notifier).restore();

      expect(
        t.container.read(sessionProvider).status,
        SessionStatus.unauthenticated,
      );
      // No point asking the server who we are without a token.
      expect(t.auth.meCalls, 0);
    });

    test('signs in when the stored token still works', () async {
      final t = build(refreshToken: 'refresh');

      await t.container.read(sessionProvider.notifier).restore();

      final state = t.container.read(sessionProvider);
      expect(state.status, SessionStatus.authenticated);
      expect(state.user?.id, 'user_1');
      expect(t.auth.meCalls, 1);
    });

    test('clears the stored token when the server rejects it', () async {
      final t = build(
        refreshToken: 'stale',
        meFailure: const ApiException(
          code: ApiException.codeUnauthorized,
          message: 'nope',
          statusCode: 401,
        ),
      );

      await t.container.read(sessionProvider.notifier).restore();

      expect(
        t.container.read(sessionProvider).status,
        SessionStatus.unauthenticated,
      );
      expect(t.tokens.clearCount, 1);
      expect(await t.tokens.hasSession, isFalse);
    });
  });

  group('accept', () {
    test('stores the tokens and signs the user in', () async {
      final t = build();
      final result = AuthResult(
        user: buildUser(name: 'Siya'),
        tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
      );

      await t.container.read(sessionProvider.notifier).accept(result);

      final state = t.container.read(sessionProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.user?.name, 'Siya');
      expect(t.tokens.saveCount, 1);
      expect(await t.tokens.readRefreshToken(), 'r');
    });
  });

  group('signOut', () {
    test('revokes server-side, clears tokens and resets state', () async {
      final t = build(refreshToken: 'r');
      await t.container.read(sessionProvider.notifier).restore();

      await t.container.read(sessionProvider.notifier).signOut();

      expect(t.auth.logoutCalls, 1);
      expect(t.tokens.clearCount, 1);
      expect(
        t.container.read(sessionProvider).status,
        SessionStatus.unauthenticated,
      );
    });

    test('still signs out locally when the server call fails', () async {
      final t = build(refreshToken: 'r');
      await t.container.read(sessionProvider.notifier).restore();
      // A network failure must not trap the user inside the app.
      t.auth.meFailure = null;

      await t.container.read(sessionProvider.notifier).signOut();

      expect(
        t.container.read(sessionProvider).status,
        SessionStatus.unauthenticated,
      );
      expect(await t.tokens.hasSession, isFalse);
    });
  });

  test('onExpired signs out without calling the server', () async {
    final t = build(refreshToken: 'r');
    await t.container.read(sessionProvider.notifier).restore();

    await t.container.read(sessionProvider.notifier).onExpired();

    expect(
      t.container.read(sessionProvider).status,
      SessionStatus.unauthenticated,
    );
    expect(t.auth.logoutCalls, 0);
    expect(t.tokens.clearCount, 1);
  });

  group('updateUser', () {
    test('replaces the cached user while signed in', () async {
      final t = build(refreshToken: 'r');
      await t.container.read(sessionProvider.notifier).restore();

      t.container
          .read(sessionProvider.notifier)
          .updateUser(buildUser(name: 'Renamed'));

      expect(t.container.read(sessionProvider).user?.name, 'Renamed');
    });

    test('is ignored while signed out', () {
      final t = build();

      t.container.read(sessionProvider.notifier).updateUser(buildUser());

      expect(t.container.read(sessionProvider).status, SessionStatus.unknown);
      expect(t.container.read(sessionProvider).user, isNull);
    });
  });

  test('the session-expiry override drives the controller', () async {
    final tokens = FakeTokenStorage(refreshToken: 'r');
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        sessionExpiryOverride,
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.notifier).restore();

    // What AuthInterceptor invokes when a refresh is rejected.
    await container.read(onSessionExpiredProvider)();

    expect(
      container.read(sessionProvider).status,
      SessionStatus.unauthenticated,
    );
    expect(await tokens.hasSession, isFalse);
  });
}
