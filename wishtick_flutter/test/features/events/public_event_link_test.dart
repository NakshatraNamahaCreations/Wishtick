import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/router/app_routes.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/auth/presentation/session_controller.dart';
import 'package:wishtick_flutter/features/events/data/invite_repository.dart';
import 'package:wishtick_flutter/features/events/presentation/public_event_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/gifting_fakes.dart';

/// Opening `wishtick.com/e/<slug>` — the link a host sends to a phone number.
///
/// The whole point of inviting by contact is that this link works for the
/// people who were invited and says so plainly for everyone else. Both halves
/// need holding down: a private event answers a stranger with a *named*
/// refusal now, not the blanket 404 it used to give.
void main() {
  late FakeInviteRepository invites;

  setUp(() => invites = FakeInviteRepository());

  Future<void> pump(WidgetTester tester, {bool signedIn = true}) async {
    tester.view
      ..physicalSize = const Size(393, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inviteRepositoryProvider.overrideWithValue(invites),
          if (signedIn) sessionProvider.overrideWith(_SignedIn.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(
            initialLocation: AppRoutes.publicEvent('siya-24th'),
            routes: [
              GoRoute(
                path: '/e/:slug',
                builder: (_, s) =>
                    PublicEventScreen(slug: s.pathParameters['slug']!),
              ),
              GoRoute(
                path: '/i/:token',
                builder: (_, s) =>
                    Scaffold(body: Text('invite ${s.pathParameters['token']}')),
              ),
              GoRoute(
                path: AppRoutes.welcome,
                builder: (_, _) => const Scaffold(body: Text('welcome')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an invited guest lands on the invitation itself', (
    tester,
  ) async {
    invites.joinToken = 'tok_abc';
    await pump(tester);

    expect(find.text('invite tok_abc'), findsOneWidget);
  });

  testWidgets('someone not on the guest list is told exactly that', (
    tester,
  ) async {
    // The refusal a host's own guest hits when the invite went to a different
    // number from the one they signed in with. "No longer available" would be
    // a lie — the link is fine, they are not on it.
    invites.failure = const ApiException(
      code: 'EVENT_INVITE_REQUIRED',
      message: 'not on the guest list',
      statusCode: 403,
    );
    await pump(tester);

    expect(find.text('This event is private'), findsOneWidget);
    expect(find.textContaining('not on the guest list'), findsOneWidget);
    // And never the wording for a dead link.
    expect(find.textContaining('no longer available'), findsNothing);
  });

  testWidgets('it names the number that was checked, which is the fix', (
    tester,
  ) async {
    // Almost every arrival here is a guest signed in with a second number.
    // Showing which one was checked is the difference between a dead end and
    // something they can act on.
    invites.failure = const ApiException(
      code: 'EVENT_INVITE_REQUIRED',
      message: 'not on the guest list',
      statusCode: 403,
    );
    await pump(tester);

    expect(find.text('Signed in as +91 98765 43210'), findsOneWidget);
    expect(
      find.textContaining('sign in with that one and open the link again'),
      findsOneWidget,
    );
  });

  testWidgets('a dead link still reads as a dead link', (tester) async {
    invites.failure = const ApiException(
      code: 'EVENT_NOT_FOUND',
      message: 'gone',
      statusCode: 404,
    );
    await pump(tester);

    expect(find.textContaining('no longer available'), findsOneWidget);
    expect(find.text('This event is private'), findsNothing);
  });

  testWidgets('arriving from the store, signed out, is asked to sign in', (
    tester,
  ) async {
    await pump(tester, signedIn: false);

    expect(find.text('You’re invited'), findsOneWidget);
    // Nothing was asked of the server: there is nobody to join as yet.
    expect(invites.joinedSlugs, isEmpty);
  });
}

/// Signed in with a number, which the refusal screen names back to them.
class _SignedIn extends SessionController {
  @override
  SessionState build() => SessionState(
    status: SessionStatus.authenticated,
    user: buildUser(phone: '+919876543210'),
  );
}
