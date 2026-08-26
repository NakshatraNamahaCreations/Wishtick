import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/router/pending_link.dart';

/// The hand-off that survives signing in.
///
/// Somebody arriving from a share link installs the app, taps Sign in, and by
/// the time they are through OTP — and possibly the whole onboarding wizard —
/// the router's own rule fires: authenticated user in the auth flow → Home.
/// Without this the invitation they came for is simply gone, and nothing on
/// Home mentions it. The cost of getting it wrong is a share that silently
/// does nothing, which is the hardest kind of bug to notice.
void main() {
  late ProviderContainer container;
  late PendingDeepLink pending;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    pending = container.read(pendingDeepLinkProvider);
  });

  test(
    'nothing is pending by default, so an ordinary sign-in goes to Home',
    () {
      expect(pending.take(), isNull);
    },
  );

  test('a remembered link is returned once and then forgotten', () {
    pending.remember('/e/summer-party');

    expect(pending.take(), '/e/summer-party');
    // Spent. Otherwise every later sign-out and back in would bounce the user
    // to an invitation they answered weeks ago.
    expect(pending.take(), isNull);
  });

  test('the newest link wins — a second tap replaces the first', () {
    pending
      ..remember('/e/first')
      ..remember('/e/second');

    expect(pending.take(), '/e/second');
  });

  test('backing out clears it, so a cancelled sign-in leads nowhere', () {
    pending
      ..remember('/e/summer-party')
      ..clear();

    expect(pending.take(), isNull);
  });

  test('it is one instance per container — the router and the screen that '
      'remembers must be talking about the same thing', () {
    container.read(pendingDeepLinkProvider).remember('/e/party');

    expect(container.read(pendingDeepLinkProvider).take(), '/e/party');
  });
}
