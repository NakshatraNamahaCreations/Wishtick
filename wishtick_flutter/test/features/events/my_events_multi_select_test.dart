import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/presentation/my_events_screen.dart';

import '../../helpers/events_fakes.dart';

/// Multi-select delete on "My Events".
///
/// Delete here is permanent — there was no way to remove an event at all
/// before, only to cancel one — so the rules worth pinning are the ones that
/// stop it happening by accident: it takes a deliberate long press to start,
/// a confirmation to finish, and it never reaches the Invites tab, where the
/// events belong to other people.
void main() {
  late FakeEventsRepository repo;

  setUp(() {
    repo = FakeEventsRepository(
      hosted: [
        buildEvent(id: 'e1', title: "Ananya's Birthday"),
        buildEvent(id: 'e2', title: "Yogi's Birthday"),
        buildEvent(id: 'e3', title: "xxx's Birthday"),
      ],
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [eventsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(theme: AppTheme.light, home: const MyEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String title) async {
    await tester.longPress(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
  }

  testWidgets('the screen starts with no selection and no delete action', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('My Events & Invites'), findsOneWidget);
    // Nothing armed until the user asks for it — a delete button sitting on a
    // list of parties is a mis-tap waiting to happen.
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.textContaining('selected'), findsNothing);
  });

  testWidgets('a plain tap opens the event, not the guest list', (
    tester,
  ) async {
    // A real router, so the push lands somewhere observable. Asserting on
    // `AppRoutes` instead would only prove the two constants differ — not
    // which of them the grid actually asks for.
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const MyEventsScreen()),
        GoRoute(
          path: '/events/:id',
          builder: (_, state) => Text('detail:${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/events/:id/guests',
          builder: (_, _) => const Text('guests'),
        ),
      ],
    );
    tester.view
      ..physicalSize = const Size(393, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [eventsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ananya's Birthday"));
    await tester.pumpAndSettle();

    // The event itself, carrying its own id — the grid used to open the guest
    // list, which left a host unable to look at their own party.
    expect(find.text('detail:e1'), findsOneWidget);
    expect(find.text('guests'), findsNothing);
  });

  testWidgets('a long press starts a selection and the bar counts it', (
    tester,
  ) async {
    await pump(tester);

    await select(tester, "Ananya's Birthday");

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await select(tester, "Yogi's Birthday");
    expect(find.text('2 selected'), findsOneWidget);
  });

  testWidgets('tapping an already-selected card unpicks it', (tester) async {
    await pump(tester);
    await select(tester, "Ananya's Birthday");
    await select(tester, "Yogi's Birthday");

    // A plain tap, not a long press: once a selection exists, tapping picks
    // rather than opens, so it must also be able to unpick.
    await tester.tap(find.text("Yogi's Birthday"));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('emptying the selection puts the normal title bar back', (
    tester,
  ) async {
    await pump(tester);
    await select(tester, "Ananya's Birthday");

    await tester.tap(find.text("Ananya's Birthday"));
    await tester.pumpAndSettle();

    expect(find.text('My Events & Invites'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('the close button abandons the selection without deleting', (
    tester,
  ) async {
    await pump(tester);
    await select(tester, "Ananya's Birthday");

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, isEmpty);
    expect(find.text('My Events & Invites'), findsOneWidget);
  });

  testWidgets('deleting asks first, and a cancel deletes nobody', (
    tester,
  ) async {
    await pump(tester);
    await select(tester, "Ananya's Birthday");

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete this event?'), findsOneWidget);
    // The wording has to say it is permanent: there is no undo, and an invite
    // link for a deleted event resolves to nothing.
    expect(find.textContaining('removed for good'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, isEmpty);
    // Still selected, so a mis-tap on Cancel does not lose the work either.
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('confirming sends every picked id in one call', (tester) async {
    await pump(tester);
    await select(tester, "Ananya's Birthday");
    await select(tester, "xxx's Birthday");

    expect(find.text('Delete 2 events?'), findsNothing);
    await confirmDelete(tester);

    expect(repo.deletedIds, ['e1', 'e3']);
    // One request for the whole selection: N of them could half-succeed and
    // leave the list in a state with no single answer to report.
    expect(find.text('2 events deleted.'), findsOneWidget);
    expect(find.text('My Events & Invites'), findsOneWidget);
  });

  testWidgets('a failed delete says so and keeps the selection', (
    tester,
  ) async {
    await pump(tester);
    await select(tester, "Ananya's Birthday");
    repo.failure = const ApiException(
      code: 'SERVER_ERROR',
      message: 'Could not delete those events.',
      statusCode: 500,
    );

    await confirmDelete(tester);

    // Kept, not cleared: the user still wants those gone, and rebuilding the
    // selection by hand after a network blip is a punishment for the network.
    expect(find.text('Could not delete those events.'), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('the Invites tab has no selection of its own', (tester) async {
    await pump(tester);
    await select(tester, "Ananya's Birthday");

    await tester.tap(find.text('Invites'));
    await tester.pumpAndSettle();

    // Switching away drops the selection rather than leaving a delete armed
    // against rows that are no longer on screen.
    expect(find.text('1 selected'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}
