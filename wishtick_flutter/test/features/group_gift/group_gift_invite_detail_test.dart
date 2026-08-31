import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/router/app_routes.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/group_gift/data/group_gift_repository.dart';
import 'package:wishtick_flutter/features/group_gift/domain/group_gift.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/group_gift_invite_detail_screen.dart';

import '../../helpers/group_gift_fakes.dart';

/// What you are being asked to chip in for, and by whom.
///
/// The invitee cannot open the group itself — they are not a participant and
/// the wishlist behind it may be private — so this screen is the only place
/// they can see what they are agreeing to before they agree to it.
void main() {
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester,
    FakeGroupGiftRepository repo, {
    ThemeData? theme,
  }) async {
    tester.view
      ..physicalSize = const Size(393, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    router = GoRouter(
      initialLocation: '/group-gifts/invites/inv_1',
      routes: [
        GoRoute(
          path: '/group-gifts/invites/:inviteId',
          builder: (_, state) => GroupGiftInviteDetailScreen(
            inviteId: state.pathParameters['inviteId']!,
          ),
        ),
        // Ahead of '/group-gifts/:id', exactly as the real router orders them:
        // otherwise that pattern matches this path with an id of "invites".
        // Declining goes back to the list; with the detail as the whole stack
        // there is nothing to pop, so it goes *to* the list instead.
        GoRoute(
          path: AppRoutes.groupGiftInvites,
          builder: (_, _) => const Scaffold(body: Text('the invitations')),
        ),
        GoRoute(
          path: '/group-gifts/:id',
          builder: (_, _) => const Scaffold(body: Text('the group')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [groupGiftRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  FakeGroupGiftRepository withDetail([GroupGiftInviteDetail? detail]) =>
      FakeGroupGiftRepository()..inviteDetail0 = detail ?? buildInviteDetail();

  testWidgets('shows the product, the money, and who is already in', (
    tester,
  ) async {
    await pump(tester, withDetail());

    expect(
      find.text('Lightbeam Android 14 Smart LED Projector'),
      findsOneWidget,
    );
    expect(find.text('Rohan asked you to chip in'), findsOneWidget);
    // The numbers the invitee is deciding on.
    expect(find.text('₹1,000 of ₹4,871 collected'), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);
    expect(find.text('₹3,871 to go · 1 contributing'), findsOneWidget);
    // And who has already put money in.
    expect(find.text('Who has chipped in'), findsOneWidget);
    expect(find.text('Rohan'), findsOneWidget);
  });

  testWidgets('says so when nobody has chipped in yet', (tester) async {
    await pump(
      tester,
      withDetail(
        buildInviteDetail(
          collectedAmountMinor: 0,
          contributorCount: 0,
          contributors: const [],
        ),
      ),
    );

    expect(find.text('Nobody has chipped in yet'), findsOneWidget);
    expect(find.text('You would be the first.'), findsOneWidget);
  });

  // Anonymity survives the invitation: someone who chose not to be named did
  // not choose to be named to whoever gets asked next.
  testWidgets('an anonymous contribution keeps its cover', (tester) async {
    await pump(
      tester,
      withDetail(
        buildInviteDetail(
          contributors: const [
            GroupGiftInviteContributor(
              userId: null,
              name: 'Someone',
              amountMinor: 100000,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Someone'), findsOneWidget);
    expect(find.text('Rohan'), findsNothing);
  });

  testWidgets('accepting answers the server and opens the group', (
    tester,
  ) async {
    final repo = withDetail();
    await pump(tester, repo);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(repo.respondedTo, [('inv_1', true)]);
    expect(find.text('the group'), findsOneWidget);
  });

  // "When clicked on Decline show confirmation alert dialog." Declining cannot
  // be taken back — only the host can send another invitation — so it asks.
  testWidgets('declining asks first', (tester) async {
    final repo = withDetail();
    await pump(tester, repo);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Decline this invitation?'), findsOneWidget);
    // Nothing has been sent yet.
    expect(repo.respondedTo, isEmpty);
  });

  testWidgets('backing out of the dialog declines nothing', (tester) async {
    final repo = withDetail();
    await pump(tester, repo);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(repo.respondedTo, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    // Still on the invitation, not dismissed out from under them.
    expect(find.text('Rohan asked you to chip in'), findsOneWidget);
  });

  // Dismissing by tapping outside is a *no*, not a silent yes. "Keep it"
  // pops false explicitly; only this path exercises the null fallback.
  testWidgets('dismissing the dialog declines nothing', (tester) async {
    final repo = withDetail();
    await pump(tester, repo);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.respondedTo, isEmpty);
    expect(find.text('the invitations'), findsNothing);
  });

  testWidgets('confirming the dialog sends the decline', (tester) async {
    final repo = withDetail();
    await pump(tester, repo);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    // The dialog's own Decline, not the button behind it.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Decline'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.respondedTo, [('inv_1', false)]);
    expect(find.text('the group'), findsNothing);
    expect(find.text('the invitations'), findsOneWidget);
  });

  // The group can close, or the invitation be answered on another device,
  // between the screen being drawn and the button being pressed.
  testWidgets('a refusal is shown, not swallowed', (tester) async {
    final repo = withDetail();
    await pump(tester, repo);
    repo.failWith = const ApiException(
      code: 'GROUP_GIFT_CLOSED',
      message: 'This group gift is closed',
      statusCode: 409,
    );

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.text('This group gift is closed'), findsOneWidget);
    expect(find.text('the group'), findsNothing);
  });

  testWidgets('a stale invitation says so instead of spinning', (tester) async {
    // Riverpod retries a failed provider, so an errored one is also loading —
    // matching the loading arm first would spin forever.
    await pump(tester, FakeGroupGiftRepository());

    expect(find.text('Could not load this invitation.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // And nothing to press while there is nothing to answer.
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('renders on a dark page', (tester) async {
    await pump(tester, withDetail(), theme: AppTheme.dark);
    expect(tester.takeException(), isNull);
    expect(find.text('Accept'), findsOneWidget);
  });
}
