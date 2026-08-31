import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/router/app_routes.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/group_gift/data/group_gift_repository.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/widgets/group_gift_invites_banner.dart';

import '../../helpers/group_gift_fakes.dart';

/// The way into an unanswered group-gift invitation.
///
/// The notification row was the only route to the invites screen, so an
/// invitation whose notification was cleared or never arrived could not be
/// reached at all — it sat pending while the host was told "already invited"
/// and the invitee saw nothing anywhere.
void main() {
  Future<void> pump(WidgetTester tester, FakeGroupGiftRepository repo) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Column(children: [GroupGiftInvitesBanner()]),
          ),
        ),
        GoRoute(
          path: AppRoutes.groupGiftInvites,
          builder: (_, _) => const Scaffold(body: Text('the invitations')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [groupGiftRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('names the group when there is exactly one waiting', (
    tester,
  ) async {
    await pump(tester, FakeGroupGiftRepository()..invites = [buildInvite()]);

    // The title, so tapping is not a leap of faith.
    expect(find.text("Chip in for Siya's birthday gift?"), findsOneWidget);
  });

  testWidgets('counts them when there are several', (tester) async {
    await pump(
      tester,
      FakeGroupGiftRepository()
        ..invites = [
          buildInvite(),
          buildInvite(id: 'inv_2', groupTitle: 'Farewell gift'),
        ],
    );

    expect(find.text('2 group gift invitations'), findsOneWidget);
  });

  testWidgets('opens the list of invitations', (tester) async {
    await pump(tester, FakeGroupGiftRepository()..invites = [buildInvite()]);

    await tester.tap(find.byType(GroupGiftInvitesBanner));
    await tester.pumpAndSettle();

    expect(find.text('the invitations'), findsOneWidget);
  });

  testWidgets('draws nothing when there is nothing to answer', (tester) async {
    await pump(tester, FakeGroupGiftRepository()..invites = []);

    expect(find.byType(InkWell), findsNothing);
    expect(tester.getSize(find.byType(GroupGiftInvitesBanner)).height, 0);
  });

  // A banner that flashes a spinner or a red error across the top of Home
  // costs more than the invitation is worth.
  testWidgets('stays out of the way when the call fails', (tester) async {
    await pump(
      tester,
      FakeGroupGiftRepository()
        ..failWith = const ApiException(
          code: ApiException.codeNetwork,
          message: 'No connection',
        ),
    );

    expect(tester.getSize(find.byType(GroupGiftInvitesBanner)).height, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
