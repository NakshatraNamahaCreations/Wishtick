import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/router/app_routes.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/group_gift/data/group_gift_repository.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/group_gift_invites_screen.dart';

import '../../helpers/group_gift_fakes.dart';

/// The list of invitations waiting on an answer.
///
/// It no longer answers them: Accept and Decline moved to the detail screen,
/// because saying yes commits money and access, and a row showing only a title
/// asks people to answer a question they have not been told.
void main() {
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester,
    FakeGroupGiftRepository repo, {
    ThemeData? theme,
  }) async {
    router = GoRouter(
      initialLocation: AppRoutes.groupGiftInvites,
      routes: [
        GoRoute(
          path: AppRoutes.groupGiftInvites,
          builder: (_, _) => const GroupGiftInvitesScreen(),
          routes: [
            GoRoute(
              path: ':inviteId',
              builder: (_, state) => Scaffold(
                body: Text('detail ${state.pathParameters['inviteId']}'),
              ),
            ),
          ],
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

  testWidgets('names the group and who asked', (tester) async {
    final repo = FakeGroupGiftRepository()
      ..invites = [
        buildInvite(groupTitle: "Siya's birthday gift", inviterName: 'Rohan'),
        buildInvite(
          id: 'inv_2',
          groupGiftId: 'gg_2',
          groupTitle: 'Farewell gift',
          inviterName: 'Sona',
        ),
      ];
    await pump(tester, repo);

    expect(find.text("Siya's birthday gift"), findsOneWidget);
    // Who asked, not just that somebody did — an invitation from nobody in
    // particular is one people ignore.
    expect(find.text('Rohan asked you to chip in'), findsOneWidget);
    expect(find.text('Sona asked you to chip in'), findsOneWidget);
  });

  testWidgets('opens the invitation rather than answering it in place', (
    tester,
  ) async {
    final repo = FakeGroupGiftRepository()..invites = [buildInvite()];
    await pump(tester, repo);

    // No answering from the list: the buttons live on the detail screen.
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Decline'), findsNothing);

    await tester.tap(find.text("Siya's birthday gift"));
    await tester.pumpAndSettle();

    expect(find.text('detail inv_1'), findsOneWidget);
    expect(repo.respondedTo, isEmpty);
  });

  testWidgets('an empty list says so rather than showing a blank page', (
    tester,
  ) async {
    await pump(tester, FakeGroupGiftRepository()..invites = []);
    expect(find.text('No invitations right now.'), findsOneWidget);
  });

  // Riverpod retries a failed provider, so an errored provider is *also*
  // loading — an error arm placed second would spin forever.
  testWidgets('a dead network offers a retry instead of a spinner', (
    tester,
  ) async {
    final repo = FakeGroupGiftRepository()
      ..failWith = const ApiException(
        code: ApiException.codeNetwork,
        message: 'No connection',
      );
    await pump(tester, repo);

    expect(find.text('Could not load your invitations.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders on a dark page', (tester) async {
    await pump(
      tester,
      FakeGroupGiftRepository()..invites = [buildInvite()],
      theme: AppTheme.dark,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Rohan asked you to chip in'), findsOneWidget);
  });
}
