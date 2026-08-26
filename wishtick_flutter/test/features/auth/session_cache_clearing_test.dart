import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/features/auth/data/auth_repository.dart';
import 'package:wishtick_flutter/features/auth/presentation/session_controller.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/profile/data/profile_repository.dart';
import 'package:wishtick_flutter/features/profile/presentation/profile_providers.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/onboarding_fakes.dart';
import '../../helpers/profile_fakes.dart';

/// Signing out has to empty the caches, not just drop the tokens.
///
/// `meProvider` stands in for the other thirty-odd providers here: it is not
/// `autoDispose`, so before this was fixed it kept the previous user's profile
/// and the next person to sign in saw their name, phone and gift counts on the
/// Profile hub until something happened to refetch. The guard test next door
/// proves the *list* is complete; this proves the clearing actually happens.
void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository(user: buildUser());
    profile = FakeProfileRepository(me: buildMe(displayName: 'Test1'));
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profile),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        onboardingRepositoryProvider.overrideWithValue(
          FakeOnboardingRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('signing out drops the cached profile, so the next user does not read '
      'the previous one', () async {
    // Somebody is signed in and the Profile hub has read them.
    expect((await container.read(meProvider.future)).displayName, 'Test1');

    await container.read(sessionProvider.notifier).signOut();

    // The next person signs in; the backend now answers with *their* profile.
    profile.me = buildMe(displayName: 'Jayanth');

    expect((await container.read(meProvider.future)).displayName, 'Jayanth');
  });

  test('a session that ends by expiry clears just as much as one that ends by '
      'a button', () async {
    expect((await container.read(meProvider.future)).displayName, 'Test1');

    // The refresh token was rejected mid-flight — no Log Out was ever tapped.
    await container.read(sessionProvider.notifier).onExpired();
    profile.me = buildMe(displayName: 'Jayanth');

    expect((await container.read(meProvider.future)).displayName, 'Jayanth');
  });

  test('signing in clears too, so a session that ended uncleanly cannot leak '
      'into the next one', () async {
    expect((await container.read(meProvider.future)).displayName, 'Test1');

    profile.me = buildMe(displayName: 'Jayanth');
    await container
        .read(sessionProvider.notifier)
        .accept(
          AuthResult(
            user: buildUser(),
            tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
          ),
        );

    expect((await container.read(meProvider.future)).displayName, 'Jayanth');
  });

  test('onExpired is safe to call twice — it is driven by failing requests, '
      'which can arrive in bursts', () async {
    await container.read(sessionProvider.notifier).onExpired();
    await container.read(sessionProvider.notifier).onExpired();

    expect(
      container.read(sessionProvider).status,
      SessionStatus.unauthenticated,
    );
  });
}
