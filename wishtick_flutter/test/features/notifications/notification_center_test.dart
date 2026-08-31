import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishtick_flutter/core/router/app_routes.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/notifications/data/notifications_repository.dart';
import 'package:wishtick_flutter/features/notifications/domain/app_notification.dart';
import 'package:wishtick_flutter/features/notifications/presentation/notification_center_screen.dart';

/// Where a notification tap goes.
///
/// Unknown types deliberately go nowhere — the server adds types faster than
/// the client ships — which makes "this type is wired up" a claim worth
/// pinning: a type nobody routed is silently inert, not broken-looking.
void main() {
  AppNotification row({
    required String type,
    String id = 'n_1',
    String refId = 'gg_1',
    String title = 'Chip in?',
  }) => AppNotification(
    id: id,
    type: type,
    category: NotificationCategory.groupGifts,
    title: title,
    body: 'Rohan invited you to chip in.',
    payload: const {},
    refId: refId,
    read: false,
    createdAt: DateTime(2026, 8, 1),
  );

  Future<void> pump(WidgetTester tester, List<AppNotification> rows) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const NotificationCenterScreen()),
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
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(
            _FakeNotificationsRepository(rows),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a group gift invite opens the invitations list', (tester) async {
    await pump(tester, [row(type: 'group_gift_invite')]);

    await tester.tap(find.text('Chip in?'));
    await tester.pumpAndSettle();

    // The list, not one group: the refId of an invite is a pair — two members
    // asking the same friend collapses to one notification — so there is no
    // single group id in it to open.
    expect(find.text('the invitations'), findsOneWidget);
  });

  testWidgets('an ordinary group gift row still opens that group', (
    tester,
  ) async {
    await pump(tester, [row(type: 'group_gift_joined', title: 'Sona joined')]);

    await tester.tap(find.text('Sona joined'));
    await tester.pumpAndSettle();

    expect(find.text('the group'), findsOneWidget);
  });
}

class _FakeNotificationsRepository implements NotificationsRepository {
  _FakeNotificationsRepository(this.rows);

  final List<AppNotification> rows;

  @override
  Future<List<AppNotification>> list({int? limit, bool? unreadOnly}) async =>
      rows;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
