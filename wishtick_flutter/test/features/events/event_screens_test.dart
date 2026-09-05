import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wishtick_flutter/core/media/media_repository.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/router/app_routes.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/auth/presentation/session_controller.dart';
import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/domain/event.dart';
import 'package:wishtick_flutter/features/events/presentation/create_event_controller.dart';
import 'package:wishtick_flutter/features/events/presentation/event_guest_detail_screen.dart';
import 'package:wishtick_flutter/features/events/presentation/event_guests_screen.dart';
import 'package:wishtick_flutter/features/events/presentation/event_invite_preview_screen.dart';
import 'package:wishtick_flutter/features/events/presentation/event_invite_templates_screen.dart';
import 'package:wishtick_flutter/features/events/presentation/invite_designer_screen.dart';
import 'package:wishtick_flutter/features/events/presentation/widgets/rsvp_status_pill.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/events_fakes.dart';
import '../../helpers/wishlist_fakes.dart';

/// A 1×1 PNG — real bytes, so a preview drawn from memory decodes.
final kPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Both create steps, as a host would have filled them in.
void fillWizard(CreateEventController draft) => draft
  ..setPersonName('Rohan')
  ..setRelation('friend', 'Friend')
  ..setTitle("Rohan's Birthday")
  ..setDate(DateTime(2030, 7, 19))
  ..setTime(const TimeOfDayValue(20, 0))
  ..setVenue('Kochi Marriott')
  ..setDescription('Come along.');

/// A session that starts authenticated as a named user.
class _SignedIn extends SessionController {
  _SignedIn(this._name);

  final String _name;

  @override
  SessionState build() => SessionState(
    status: SessionStatus.authenticated,
    user: buildUser(name: _name),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEventsRepository repo;
  late FakeMediaRepository media;

  /// share_plus has no plugin behind it in a test, and its future would never
  /// complete — leaving the Download button spinning and `pumpAndSettle`
  /// hanging on an animation that never stops.
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async => 'dev.test');

    media = FakeMediaRepository();
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
    String? signedInAs,
  }) async {
    // A phone, not the 800×600 default: the download button and the last few
    // guest rows sit below the fold at that size and cannot be tapped.
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventsRepositoryProvider.overrideWithValue(repo),
          mediaRepositoryProvider.overrideWithValue(media),
          // The invitation's "Hosted by" line reads the signed-in user.
          if (signedInAs != null)
            sessionProvider.overrideWith(() => _SignedIn(signedInAs)),
        ],
        child: MaterialApp(theme: theme ?? AppTheme.light, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The same, under a router — for screens that `push` or `go`.
  ///
  /// [draft] fills the create wizard before the first frame, the way a host
  /// arrives at these screens. Returns the container so a test can read the
  /// wizard afterwards.
  Future<ProviderContainer> pumpRouted(
    WidgetTester tester, {
    required String initialLocation,
    required List<RouteBase> routes,
    String? signedInAs,
    void Function(CreateEventController draft)? draft,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        eventsRepositoryProvider.overrideWithValue(repo),
        mediaRepositoryProvider.overrideWithValue(media),
        if (signedInAs != null)
          sessionProvider.overrideWith(() => _SignedIn(signedInAs)),
      ],
    );
    addTearDown(container.dispose);
    draft?.call(container.read(createEventProvider.notifier));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(
            initialLocation: initialLocation,
            routes: routes,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// The event page with Share beneath it, as stubs — enough to see where
  /// the wizard lands, without the share screen's own concerns.
  GoRoute eventRoutes() => GoRoute(
    path: '/events/:id',
    builder: (_, s) => Scaffold(body: Text('event ${s.pathParameters['id']}')),
    routes: [
      GoRoute(
        path: 'share',
        builder: (_, s) =>
            Scaffold(body: Text('share ${s.pathParameters['id']}')),
      ),
    ],
  );

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
    setUpAll(() {
      // The style grid renders the real canvas, whose Google faces would
      // otherwise fetch — and hang — in a test.
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    testWidgets('Next is dead until a style is chosen', (tester) async {
      await pump(tester, const EventInviteTemplatesScreen(eventId: 'evt_1'));
      // The method sheet opens over it first.
      await tester.tap(find.text('Use Wishtick Templates'));
      await tester.pumpAndSettle();

      final next = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Next'),
      );
      // A background is pre-selected — every style needs one to preview on —
      // but a style is the host's choice, so nothing is armed yet.
      expect(next.onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('invite-style-classic')));
      await tester.pumpAndSettle();

      final armed = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Next'),
      );
      expect(armed.onPressed, isNotNull);
    });

    testWidgets('the Anniversary tab hides birthday-only backgrounds and '
        'styles', (tester) async {
      await pump(tester, const EventInviteTemplatesScreen(eventId: 'evt_1'));
      await tester.tap(find.text('Use Wishtick Templates'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('invite-bg-happy_birthday')), findsOne);
      expect(find.byKey(const ValueKey('invite-style-playful')), findsOne);

      await tester.tap(find.byKey(const ValueKey('template-tab-Anniversary')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('invite-bg-happy_birthday')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('invite-style-playful')), findsNothing);
      // The occasion-neutral ones stay.
      expect(find.byKey(const ValueKey('invite-bg-wishes')), findsOne);
      expect(find.byKey(const ValueKey('invite-style-classic')), findsOne);
    });

    testWidgets('Next opens the designer on the chosen background with the '
        'style already laid out', (tester) async {
      await pump(tester, const EventInviteTemplatesScreen(eventId: 'evt_1'));
      await tester.tap(find.text('Use Wishtick Templates'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('invite-bg-wishes')));
      await tester.pumpAndSettle();
      // Third of five styles, so the second grid row — below the fold on a
      // 900px surface. A tap outside the viewport is silently dropped.
      final script = find.byKey(const ValueKey('invite-style-script'));
      await tester.ensureVisible(script);
      await tester.pumpAndSettle();
      await tester.tap(script);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();

      final designer = tester.widget<InviteDesignerScreen>(
        find.byType(InviteDesignerScreen),
      );
      expect(designer.initial.backgroundKey, 'wishes');
      // Pre-filled from the event, not blank: the old template path could
      // not be edited, and a blank canvas is not a template.
      expect(designer.initial.layers, isNotEmpty);
      expect(
        designer.initial.layers.map((l) => l.text),
        contains("Siya's 24th"),
      );
      // Nothing was saved yet — the card only exists once the designer exports
      // it, so backing out of the designer leaves the event untouched.
      expect(repo.updateCalls, isEmpty);
    });

    testWidgets('previews carry "Hosted by" the signed-in user, not the '
        'person the party is for', (tester) async {
      await pump(
        tester,
        const EventInviteTemplatesScreen(eventId: 'evt_1'),
        signedInAs: 'Ananya',
      );
      await tester.tap(find.text('Use Wishtick Templates'));
      await tester.pumpAndSettle();

      // The event is Siya's; Ananya is the account designing it.
      expect(find.text('Hosted by Ananya'), findsWidgets);
      expect(find.text('Hosted by Siya'), findsNothing);
    });

    testWidgets('a self-event carries no "Hosted by" line at all', (
      tester,
    ) async {
      repo.event = buildEvent(forSelf: true);
      await pump(
        tester,
        const EventInviteTemplatesScreen(eventId: 'evt_1'),
        signedInAs: 'Ananya',
      );
      await tester.tap(find.text('Use Wishtick Templates'));
      await tester.pumpAndSettle();

      // The headline already names the host; a second line would say it twice.
      expect(find.textContaining('Hosted by'), findsNothing);
    });

    testWidgets('previews are drawn with this event, not placeholder copy', (
      tester,
    ) async {
      await pump(tester, const EventInviteTemplatesScreen(eventId: 'evt_1'));
      await tester.tap(find.text('Use Wishtick Templates'));
      await tester.pumpAndSettle();

      // One per style card — the title appears on every preview.
      expect(find.text("Siya's 24th"), findsWidgets);
      expect(find.text('Mysore Socials'), findsWidgets);
      expect(find.text('Your Celebration'), findsNothing);
    });

    group('for an event still being created', () {
      testWidgets('the previews read the wizard, and nothing is fetched', (
        tester,
      ) async {
        await pumpRouted(
          tester,
          initialLocation: AppRoutes.createEventInvite,
          routes: [
            GoRoute(
              path: AppRoutes.createEventInvite,
              builder: (_, _) => const EventInviteTemplatesScreen(),
            ),
          ],
          signedInAs: 'Ananya',
          draft: fillWizard,
        );
        await tester.tap(find.text('Use Wishtick Templates'));
        await tester.pumpAndSettle();

        expect(find.text("Rohan's Birthday"), findsWidgets);
        expect(find.text('Kochi Marriott'), findsWidgets);
        expect(find.text('Hosted by Ananya'), findsWidgets);
        expect(find.text('Your Celebration'), findsNothing);
        // There is no event to fetch, and none was made to get one.
        expect(repo.createCalls, isEmpty);
      });

      testWidgets('Done keeps the card in the wizard and opens the preview '
          '— no upload, no event', (tester) async {
        final container = await pumpRouted(
          tester,
          initialLocation: AppRoutes.createEventInvite,
          routes: [
            GoRoute(
              path: AppRoutes.createEventInvite,
              builder: (_, _) => const EventInviteTemplatesScreen(),
            ),
            GoRoute(
              path: AppRoutes.createEventInvitePreview,
              builder: (_, _) => const EventInvitePreviewScreen(),
            ),
          ],
          draft: fillWizard,
        );
        await tester.tap(find.text('Use Wishtick Templates'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('invite-style-classic')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
        await tester.pumpAndSettle();

        // What Done does, minus the rasterising: hand over the PNG, then pop
        // with the design.
        final designer = tester.widget<InviteDesignerScreen>(
          find.byType(InviteDesignerScreen),
        );
        await designer.onDone!(kPng, designer.initial);
        Navigator.of(
          tester.element(find.byType(InviteDesignerScreen)),
        ).pop(designer.initial);
        await tester.pumpAndSettle();

        expect(find.text('Preview\nYour Invite'), findsOneWidget);
        expect(
          container.read(createEventProvider).invitation?.fileName,
          'invitation.png',
        );
        expect(media.uploadCalls, isEmpty);
        expect(repo.updateCalls, isEmpty);
        expect(repo.createCalls, isEmpty);
      });
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

    testWidgets('for an existing draft, Skip publishes it and lands on Share', (
      tester,
    ) async {
      repo.event = buildEvent(inviteMediaUrl: 'https://cdn.test/invite.png');
      await pumpRouted(
        tester,
        initialLocation: AppRoutes.eventInvitePreview('evt_1'),
        routes: [
          GoRoute(
            path: '/events/:id/invite/preview',
            builder: (_, s) =>
                EventInvitePreviewScreen(eventId: s.pathParameters['id']),
          ),
          eventRoutes(),
        ],
      );

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.text('share evt_1'), findsOneWidget);
      expect(repo.publishCalls, ['evt_1']);
      expect(repo.createCalls, isEmpty);
    });

    group('for an event still being created', () {
      /// The preview, a stub wishlist form that saves [saves] or backs out,
      /// and the event page with Share beneath it.
      List<RouteBase> routes({Wishlist? saves}) => [
        GoRoute(
          path: AppRoutes.createEventInvitePreview,
          builder: (_, _) => const EventInvitePreviewScreen(),
        ),
        GoRoute(
          path: AppRoutes.wishlistCreate,
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => context.pop(saves),
                  child: const Text('Save list'),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Back out'),
                ),
              ],
            ),
          ),
        ),
        eventRoutes(),
      ];

      Future<ProviderContainer> pumpPreview(
        WidgetTester tester, {
        Wishlist? saves,
      }) => pumpRouted(
        tester,
        initialLocation: AppRoutes.createEventInvitePreview,
        routes: routes(saves: saves),
        draft: (n) {
          fillWizard(n);
          n.setInvitation(kPng, 'invitation.png');
        },
      );

      testWidgets('draws the card from the wizard; nothing exists yet', (
        tester,
      ) async {
        await pumpPreview(tester);

        final image = tester.widget<Image>(find.byType(Image));
        expect((image.image as MemoryImage).bytes, kPng);
        expect(find.text('Create Wishlist'), findsOneWidget);
        expect(find.text('Skip for now'), findsOneWidget);
        expect(repo.createCalls, isEmpty);
        expect(media.uploadCalls, isEmpty);
      });

      testWidgets('Skip creates, publishes and lands on Share', (tester) async {
        final container = await pumpPreview(tester);

        await tester.tap(find.text('Skip for now'));
        await tester.pumpAndSettle();

        expect(find.text('share evt_1'), findsOneWidget);
        expect(media.uploadCalls, [MediaPurpose.eventInvite]);
        expect(repo.createCalls.single['inviteMediaId'], 'media_1');
        expect(repo.publishCalls, ['evt_1']);
        // The wizard is over: the next Create Event starts blank.
        expect(container.read(createEventProvider).invitation, isNull);
        expect(container.read(createEventProvider).title, isEmpty);
      });

      testWidgets('Create Wishlist links the new list, then shares', (
        tester,
      ) async {
        await pumpPreview(tester, saves: buildWishlist(id: 'wl_new'));

        await tester.tap(find.text('Create Wishlist'));
        await tester.pumpAndSettle();
        // Opening the form makes nothing.
        expect(repo.createCalls, isEmpty);

        await tester.tap(find.text('Save list'));
        await tester.pumpAndSettle();

        expect(find.text('share evt_1'), findsOneWidget);
        expect(repo.createCalls.single['wishlistIds'], ['wl_new']);
        expect(repo.publishCalls, ['evt_1']);
      });

      testWidgets('backing out of the wishlist form creates nothing', (
        tester,
      ) async {
        await pumpPreview(tester);

        await tester.tap(find.text('Create Wishlist'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Back out'));
        await tester.pumpAndSettle();

        // Still on the preview, with nothing made on the host's behalf.
        expect(find.text('Preview\nYour Invite'), findsOneWidget);
        expect(repo.createCalls, isEmpty);
        expect(repo.publishCalls, isEmpty);
        expect(media.uploadCalls, isEmpty);
      });

      testWidgets('a refusal is shown here, with nothing half-made', (
        tester,
      ) async {
        repo.failure = const ApiException(
          code: 'EVENT_LIMIT_REACHED',
          message: 'limit',
          statusCode: 409,
        );
        await pumpPreview(tester);

        await tester.tap(find.text('Skip for now'));
        await tester.pumpAndSettle();

        expect(find.textContaining('as many events'), findsOneWidget);
        expect(find.text('Preview\nYour Invite'), findsOneWidget);
        expect(repo.publishCalls, isEmpty);
      });
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
