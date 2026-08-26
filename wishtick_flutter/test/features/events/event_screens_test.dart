import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/domain/event.dart';
import 'package:wishtick_flutter/features/events/presentation/event_guest_detail_screen.dart';
import 'package:wishtick_flutter/features/events/presentation/event_guests_screen.dart';
import 'package:wishtick_flutter/features/events/presentation/event_invite_preview_screen.dart';
import 'package:wishtick_flutter/features/events/presentation/event_invite_templates_screen.dart';
import 'package:wishtick_flutter/features/events/presentation/widgets/rsvp_status_pill.dart';

import '../../helpers/events_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEventsRepository repo;

  /// share_plus has no plugin behind it in a test, and its future would never
  /// complete — leaving the Download button spinning and `pumpAndSettle`
  /// hanging on an animation that never stops.
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async => 'dev.test');

    repo = FakeEventsRepository(
      invites: [
        buildInviteRow(
          id: 'i1',
          name: 'Rohan',
          rsvp: RsvpResponse.yes,
          plusOnes: 2,
        ),
        buildInviteRow(
          id: 'i2',
          name: 'Sona',
          rsvp: RsvpResponse.yes,
          plusOnes: 3,
        ),
        buildInviteRow(
          id: 'i3',
          name: 'Vihan',
          rsvp: RsvpResponse.maybe,
          plusOnes: 2,
        ),
        buildInviteRow(
          id: 'i4',
          name: 'Mridhanvi',
          rsvp: RsvpResponse.no,
          plusOnes: 1,
        ),
        buildInviteRow(id: 'i5', name: 'Unanswered'),
      ],
    );
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
  }) async {
    // A phone, not the 800×600 default: the download button and the last few
    // guest rows sit below the fold at that size and cannot be tapped.
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(theme: theme ?? AppTheme.light, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Guest list (4099:1256)', () {
    testWidgets('counts come from the rows on screen, not a second source', (
      tester,
    ) async {
      await pump(tester, const EventGuestsScreen(eventId: 'evt_1'));

      expect(find.text('Guests List'), findsOneWidget);
      expect(find.text("Siya's 24th"), findsOneWidget);

      // Confirmed 2, Maybe 1, Declined 1 — "no reply" counts toward none.
      expect(find.text('Confirmed'), findsWidgets);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2));
    });

    testWidgets('a plus-one line is pluralised', (tester) async {
      await pump(tester, const EventGuestsScreen(eventId: 'evt_1'));

      // Rohan and Vihan both bring two.
      expect(find.text('+ 2 Guests'), findsNWidgets(2));
      expect(find.text('+ 1 Guest'), findsOneWidget);
      // Someone bringing nobody gets no line at all.
      expect(find.text('+ 0 Guests'), findsNothing);
    });

    testWidgets('the Declined chip narrows the list to declines', (
      tester,
    ) async {
      await pump(tester, const EventGuestsScreen(eventId: 'evt_1'));

      // The default test font draws every glyph as a full-em square, so the
      // chip row is far wider here than on a device and the last chip starts
      // off-screen.
      final declined = find.byKey(const ValueKey('guest-filter-Declined'));
      await tester.ensureVisible(declined);
      await tester.pumpAndSettle();
      await tester.tap(declined);
      await tester.pumpAndSettle();

      expect(find.text('Mridhanvi'), findsOneWidget);
      expect(find.text('Rohan'), findsNothing);
    });

    testWidgets('an event nobody was invited to says so', (tester) async {
      repo.guests = [];
      await pump(tester, const EventGuestsScreen(eventId: 'evt_1'));

      expect(find.text('Nobody has been invited yet.'), findsOneWidget);
    });
  });

  group('Download sheet (4096:206)', () {
    testWidgets('PDF is pre-selected and Cancel exports nothing', (
      tester,
    ) async {
      await pump(tester, const EventGuestsScreen(eventId: 'evt_1'));

      await tester.tap(find.text('Download Guest List'));
      await tester.pumpAndSettle();

      expect(find.text('Best for printing and sharing'), findsOneWidget);
      expect(find.text('Best for editing and analytics'), findsOneWidget);
      expect(find.text('Best for simple data export'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.exportCalls, isEmpty);
    });

    testWidgets('choosing CSV asks the server for CSV', (tester) async {
      await pump(tester, const EventGuestsScreen(eventId: 'evt_1'));

      await tester.tap(find.text('Download Guest List'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CSV'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download'));
      // Bounded pumps, not pumpAndSettle: the share sheet that follows the
      // export is a platform call with no plugin behind it here, and the
      // button's spinner keeps animating while it is awaited.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(repo.exportCalls, [GuestListFormat.csv]);
    });
  });

  group('Guest details (4096:162)', () {
    testWidgets('shows the contact rows and the plus-one count', (
      tester,
    ) async {
      await pump(
        tester,
        const EventGuestDetailScreen(eventId: 'evt_1', inviteId: 'i1'),
      );

      expect(find.text('Rohan'), findsOneWidget);
      expect(find.text('+ 2 Additional Guests'), findsOneWidget);
      expect(find.text('WishMate'), findsOneWidget);
      expect(find.text('Added on'), findsOneWidget);
      expect(find.text('RSVP on'), findsOneWidget);
    });

    testWidgets('a missing value reads as a dash, never as a blank', (
      tester,
    ) async {
      repo.guests = [buildInviteRow(id: 'i9', name: 'Anon', username: null)];
      await pump(
        tester,
        const EventGuestDetailScreen(eventId: 'evt_1', inviteId: 'i9'),
      );

      // The handle and "RSVP on" are both unknown.
      expect(find.text('—'), findsNWidgets(2));
    });

    testWidgets('removing asks first, and a cancel removes nobody', (
      tester,
    ) async {
      await pump(
        tester,
        const EventGuestDetailScreen(eventId: 'evt_1', inviteId: 'i1'),
      );

      await tester.tap(find.text('Remove From Guest List'));
      await tester.pumpAndSettle();
      expect(find.text('Remove from guest list?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.revoked, isEmpty);
    });

    testWidgets('confirming removes them', (tester) async {
      await pump(
        tester,
        const EventGuestDetailScreen(eventId: 'evt_1', inviteId: 'i1'),
      );

      await tester.tap(find.text('Remove From Guest List'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(repo.revoked, ['i1']);
    });
  });

  group('Template picker (263:900)', () {
    testWidgets('Next is dead until a design is chosen', (tester) async {
      await pump(tester, const EventInviteTemplatesScreen(eventId: 'evt_1'));
      // The method sheet opens over it first.
      await tester.tap(find.text('Use Wishtick Templates'));
      await tester.pumpAndSettle();

      final next = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Next'),
      );
      expect(next.onPressed, isNull);

      await tester.tap(find.text('Golden Bloom').first);
      await tester.pumpAndSettle();

      final armed = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Next'),
      );
      expect(armed.onPressed, isNotNull);
    });

    testWidgets('the Anniversary tab hides birthday-only designs', (
      tester,
    ) async {
      await pump(tester, const EventInviteTemplatesScreen(eventId: 'evt_1'));
      await tester.tap(find.text('Use Wishtick Templates'));
      await tester.pumpAndSettle();

      expect(find.text('Golden Bloom'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('template-tab-Anniversary')));
      await tester.pumpAndSettle();

      expect(find.text('Golden Bloom'), findsNothing);
      expect(find.text('Evergreen'), findsWidgets);
    });

    testWidgets('choosing a design drops a previously uploaded file', (
      tester,
    ) async {
      // The two are alternatives and the upload wins wherever the invitation
      // is drawn, so leaving it in place would make picking a design look
      // like it did nothing.
      await pump(tester, const EventInviteTemplatesScreen(eventId: 'evt_1'));
      await tester.tap(find.text('Use Wishtick Templates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Golden Bloom').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();

      final call = repo.updateCalls.single;
      expect(call['templateId'], 'tpl_1');
      expect(call['clearInviteMedia'], isTrue);
    });
  });

  group('Invite preview (263:1014)', () {
    testWidgets('renders the resolved card from the saved design', (
      tester,
    ) async {
      repo.event = buildEvent(
        inviteTemplate: const InviteTemplateChoice(
          templateId: 'tpl_1',
          colorVariant: 'plum',
          fields: {},
        ),
      );
      await pump(tester, const EventInvitePreviewScreen(eventId: 'evt_1'));

      expect(find.text('Preview\nYour Invite'), findsOneWidget);
      expect(find.text('SUNDAY 19 JULY AT 8PM'), findsOneWidget);
      expect(find.text('MYSORE SOCIALS'), findsOneWidget);
      expect(find.text('Create Wishlist'), findsOneWidget);
    });

    testWidgets('an uploaded PDF is described, not faked into a card', (
      tester,
    ) async {
      repo.event = buildEvent(inviteMediaUrl: 'https://cdn.test/invite.pdf');
      await pump(tester, const EventInvitePreviewScreen(eventId: 'evt_1'));

      expect(
        find.text('Your uploaded invitation will be sent as it is.'),
        findsOneWidget,
      );
    });
  });

  group('RSVP pill', () {
    testWidgets('uses the guest list\'s words, not the wire values', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(
          body: Column(
            children: [
              RsvpStatusPill(rsvp: RsvpResponse.yes),
              RsvpStatusPill(rsvp: RsvpResponse.maybe),
              RsvpStatusPill(rsvp: RsvpResponse.no),
              RsvpStatusPill(rsvp: RsvpResponse.pending),
            ],
          ),
        ),
      );

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('May be'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('No reply'), findsOneWidget);
    });
  });

  group('Dark mode', () {
    testWidgets('every Sprint 7 screen renders on a dark page', (tester) async {
      repo.event = buildEvent(
        inviteTemplate: const InviteTemplateChoice(
          templateId: 'tpl_1',
          colorVariant: 'plum',
          fields: {},
        ),
      );

      await pump(
        tester,
        const EventGuestsScreen(eventId: 'evt_1'),
        theme: AppTheme.dark,
      );
      expect(tester.takeException(), isNull);

      await pump(
        tester,
        const EventGuestDetailScreen(eventId: 'evt_1', inviteId: 'i1'),
        theme: AppTheme.dark,
      );
      expect(tester.takeException(), isNull);

      await pump(
        tester,
        const EventInvitePreviewScreen(eventId: 'evt_1'),
        theme: AppTheme.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
