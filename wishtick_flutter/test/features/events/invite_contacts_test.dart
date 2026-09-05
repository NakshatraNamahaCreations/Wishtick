import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/auth/presentation/session_controller.dart';
import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/presentation/invite_contacts_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/events_fakes.dart';

/// Inviting people who are not on Wishtick yet, by picking them out of the
/// host's address book.
void main() {
  Contact contact(String name, List<String> numbers) => Contact(
    id: name,
    displayName: name,
    phones: numbers.map((n) => Phone(number: n)).toList(),
  );

  group('reading the address book', () {
    test('every number becomes its own candidate, in E.164', () {
      // A person with a mobile and a landline is two rows: the host has to
      // choose which one the invitation goes to.
      final people = candidatesFrom([
        contact('Priya Nair', ['98765 43210', '+91 80 4567 8900']),
      ], defaultDialCode: '+91');

      expect(people.map((p) => p.phone), ['+919876543210', '+918045678900']);
      expect(people.every((p) => p.name == 'Priya Nair'), isTrue);
    });

    test('the same number saved twice appears once', () {
      final people = candidatesFrom([
        contact('Priya', ['98765 43210']),
        contact('Priya Nair (work)', ['+919876543210']),
      ], defaultDialCode: '+91');

      expect(people, hasLength(1));
    });

    test('what is not a phone number is left out, not offered', () {
      // Inviting an extension or a note field makes a guest-list row nobody
      // can ever claim.
      final people = candidatesFrom([
        contact('Front desk', ['101']),
        contact('Real person', ['9876543210']),
      ], defaultDialCode: '+91');

      expect(people.map((p) => p.name), ['Real person']);
    });

    test('a contact with no name is shown by its number', () {
      final people = candidatesFrom([
        contact('', ['9876543210']),
      ], defaultDialCode: '+91');

      expect(people.single.name, '+91 98765 43210');
    });

    test('the list is alphabetical, so a long address book is navigable', () {
      final people = candidatesFrom([
        contact('Zara', ['9000000001']),
        contact('anil', ['9000000002']),
        contact('Meera', ['9000000003']),
      ], defaultDialCode: '+91');

      expect(people.map((p) => p.name), ['anil', 'Meera', 'Zara']);
    });
  });

  group('the picker', () {
    late FakeEventsRepository repo;

    /// Stands in for the device's address book, so no permission or real
    /// contacts are needed to exercise everything that happens after.
    ContactsOutcome outcome = const ContactsReady([
      ContactCandidate(name: 'Anil Kumar', phone: '+919000000001'),
      ContactCandidate(name: 'Meera Rao', phone: '+919000000002'),
    ]);

    /// How many times the OS settings page was asked for.
    var openedSettings = 0;

    setUp(() {
      repo = FakeEventsRepository();
      openedSettings = 0;
      outcome = const ContactsReady([
        ContactCandidate(name: 'Anil Kumar', phone: '+919000000001'),
        ContactCandidate(name: 'Meera Rao', phone: '+919000000002'),
      ]);
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(393, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventsRepositoryProvider.overrideWithValue(repo),
            contactsReaderProvider.overrideWithValue((_) async => outcome),
            settingsOpenerProvider.overrideWithValue(() async {
              openedSettings++;
            }),
            sessionProvider.overrideWith(_SignedIn.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: InviteContactsScreen(event: buildEvent()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('says who can get in, before anything is picked', (
      tester,
    ) async {
      await pump(tester);

      expect(
        find.textContaining('Only the people you tick can open this event'),
        findsOneWidget,
      );
      // Nothing armed until somebody is chosen.
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('picking people sends their numbers, not their names', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Anil Kumar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Invite 1'));
      await tester.pumpAndSettle();

      // Field by field: a record holding a List compares that List by
      // identity, so two equal-looking calls are never `==`.
      expect(repo.phoneInviteCalls, hasLength(1));
      expect(repo.phoneInviteCalls.single.$1, 'evt_1');
      expect(repo.phoneInviteCalls.single.$2, ['+919000000001']);
    });

    testWidgets('search narrows the list without losing what is ticked', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Anil Kumar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'meera');
      await tester.pumpAndSettle();

      expect(find.text('Anil Kumar'), findsNothing);
      expect(find.text('Meera Rao'), findsOneWidget);
      // Still one ticked, even though they are off screen.
      expect(find.widgetWithText(ElevatedButton, 'Invite 1'), findsOneWidget);
    });

    testWidgets('a refusal explains itself instead of showing an empty list', (
      tester,
    ) async {
      outcome = const ContactsRefused(permanently: false);
      await pump(tester);

      expect(find.text('Wishtick cannot see your contacts'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets(
      'a permanent refusal offers Settings, and actually goes there',
      (tester) async {
        // The label alone proves nothing: a button reading "Open Settings" that
        // re-asks a permission the OS will never grant again looks identical
        // and does nothing at all.
        outcome = const ContactsRefused(permanently: true);
        await pump(tester);

        expect(find.text('Open Settings'), findsOneWidget);
        expect(find.text('Try again'), findsNothing);
        expect(find.textContaining('will not ask again'), findsOneWidget);

        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();
        expect(openedSettings, 1);
      },
    );

    testWidgets('an ordinary refusal re-asks rather than opening Settings', (
      tester,
    ) async {
      outcome = const ContactsRefused(permanently: false);
      await pump(tester);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(openedSettings, 0);
    });

    testWidgets('an address book with no usable numbers says so', (
      tester,
    ) async {
      outcome = const ContactsReady([]);
      await pump(tester);

      expect(
        find.textContaining('No contacts with a phone number'),
        findsOneWidget,
      );
    });

    testWidgets('a refused invite keeps the selection and says why', (
      tester,
    ) async {
      repo.failure = const ApiException(
        code: 'INVITE_LIMIT_REACHED',
        message: 'full',
        statusCode: 409,
      );
      await pump(tester);

      await tester.tap(find.text('Anil Kumar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Invite 1'));
      await tester.pumpAndSettle();

      expect(
        find.text('This event has reached its guest limit.'),
        findsOneWidget,
      );
      // Still on the picker, still ticked, so the host can change it.
      expect(find.widgetWithText(ElevatedButton, 'Invite 1'), findsOneWidget);
    });
  });

  group('the permission explanation', () {
    testWidgets('says what is read, what is sent, and who can get in', (
      tester,
    ) async {
      // The OS prompt is one line the app does not control, and a permission
      // sheet out of nowhere is the one people refuse — permanently, on
      // Android. This is what earns the tap.
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      final answer = confirmContactsPermission(ctx);
      await tester.pumpAndSettle();

      expect(find.text('Invite people from your contacts'), findsOneWidget);
      expect(find.textContaining('stay on your phone'), findsOneWidget);
      expect(find.textContaining('Only the people you invite'), findsOneWidget);
      expect(find.textContaining('app store'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(await answer, isTrue);
    });

    testWidgets('"Not now" answers no, so the OS is never asked', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      final answer = confirmContactsPermission(ctx);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(await answer, isFalse);
    });
  });
}

/// A host signed in with an Indian number, which is what decides the country
/// assumed for a contact saved without one.
class _SignedIn extends SessionController {
  @override
  SessionState build() => SessionState(
    status: SessionStatus.authenticated,
    user: buildUser(phone: '+919876543210'),
  );
}
