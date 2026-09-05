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
import 'package:wishtick_flutter/features/home/data/home_repository.dart';

import '../../helpers/group_gift_fakes.dart';
import '../../helpers/home_fakes.dart';

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
          path: AppRoutes.groupGiftContributed(':id'),
          builder: (_, _) => const Scaffold(body: Text('the confirmation')),
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
        overrides: [
          groupGiftRepositoryProvider.overrideWithValue(repo),
          // Answering refreshes Home — the chip-in card there is the same
          // invitation — so Home's repository has to be a fake here too.
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
        ],
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

  // Paying is the yes. There is no bare Accept: the server takes a
  // contribution from an invitee as their answer, so a separate button would
  // only be a second way to say the same thing.
  testWidgets('Contribute to Gift pays, which is how the invite is accepted', (
    tester,
  ) async {
    final repo = withDetail();
    await pump(tester, repo);

    await tester.tap(find.text('Contribute to Gift'));
    await tester.pumpAndSettle();
    // The chips come off the invitation, since the invitee cannot read the
    // group they would otherwise come from.
    // ₹2,000, not ₹1,000: Rohan's contribution row behind the sheet says
    // ₹1,000 too, and the finder would not know which one was meant.
    await tester.tap(find.text('₹2,000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay ₹2,000'));
    await tester.pumpAndSettle();

    expect(
      repo.calls.where((c) => c.startsWith('contribute:200000:')),
      hasLength(1),
    );
    // Not answered a second time by hand — the payment did it.
    expect(repo.respondedTo, isEmpty);
    expect(find.text('the confirmation'), findsOneWidget);
  });

  // Closing the sheet without paying is not an answer either.
  testWidgets('backing out of the sheet pays nothing and answers nothing', (
    tester,
  ) async {
    final repo = withDetail();
    await pump(tester, repo);

    await tester.tap(find.text('Contribute to Gift'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(repo.calls.where((c) => c.startsWith('contribute:')), isEmpty);
    expect(repo.respondedTo, isEmpty);
    expect(find.text('Rohan asked you to chip in'), findsOneWidget);
  });

  // "Maybe Later" is deliberately not an answer: the invitation stays pending
  // and the card stays on Home, to be decided another time.
  testWidgets('Maybe Later goes back without answering', (tester) async {
    final repo = withDetail();
    await pump(tester, repo);

    await tester.tap(find.text('Maybe Later'));
    await tester.pumpAndSettle();

    expect(repo.respondedTo, isEmpty);
    expect(repo.calls.where((c) => c.startsWith('contribute:')), isEmpty);
    expect(find.text('the invitations'), findsOneWidget);
  });

  // The countdown the design puts on the header (`316:536` — "2 days left").
  testWidgets('says how long is left to pay', (tester) async {
    await pump(
      tester,
      withDetail(
        buildInviteDetail(
          deadline: DateTime.now().add(const Duration(days: 2)),
        ),
      ),
    );

    expect(find.text('2 days left'), findsOneWidget);
  });

  testWidgets('says nothing about a deadline there is none of', (tester) async {
    await pump(tester, withDetail());

    expect(find.textContaining('left'), findsNothing);
  });

  // A countdown that has run out is worse than no countdown: '-3 days left'
  // is nonsense, and 'today' would be a lie.
  testWidgets('says nothing once the deadline has gone by', (tester) async {
    await pump(
      tester,
      withDetail(
        buildInviteDetail(
          deadline: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ),
    );

    expect(find.textContaining('left'), findsNothing);
    expect(find.textContaining('Last day'), findsNothing);
  });

  // "When clicked on Decline show confirmation alert dialog." Declining cannot
  // be taken back — only the host can send another invitation — so it asks.
  testWidgets('declining asks first', (tester) async {
    final repo = withDetail();
    await pump(tester, repo);

    await tester.tap(find.text('Not Interested? Decline Invitation'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Decline this invitation?'), findsOneWidget);
    // Nothing has been sent yet.
    expect(repo.respondedTo, isEmpty);
  });

  testWidgets('backing out of the dialog declines nothing', (tester) async {
    final repo = withDetail();
    await pump(tester, repo);

    await tester.tap(find.text('Not Interested? Decline Invitation'));
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

    await tester.tap(find.text('Not Interested? Decline Invitation'));
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

    await tester.tap(find.text('Not Interested? Decline Invitation'));
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

    await tester.tap(find.text('Not Interested? Decline Invitation'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Decline'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This group gift is closed'), findsOneWidget);
    expect(find.text('the invitations'), findsNothing);
  });

  testWidgets('a stale invitation says so instead of spinning', (tester) async {
    // Riverpod retries a failed provider, so an errored one is also loading —
    // matching the loading arm first would spin forever.
    await pump(tester, FakeGroupGiftRepository());

    expect(find.text('Could not load this invitation.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // And nothing to press while there is nothing to answer.
    expect(find.text('Contribute to Gift'), findsNothing);
    expect(find.text('Not Interested? Decline Invitation'), findsNothing);
  });

  testWidgets('renders on a dark page', (tester) async {
    await pump(tester, withDetail(), theme: AppTheme.dark);
    expect(tester.takeException(), isNull);
    expect(find.text('Contribute to Gift'), findsOneWidget);
  });
}
