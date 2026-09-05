import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_image.dart';
import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/domain/invited_event.dart';
import 'package:wishtick_flutter/features/events/presentation/my_events_screen.dart';

import '../../helpers/events_fakes.dart';

/// The Invites tab: other people's events, as their guest sees them.
///
/// The card used to draw only the event's cover, which an event made in the
/// app never has — it carries an invitation instead — so every card here was
/// a blank tile.
void main() {
  late FakeEventsRepository repo;

  setUp(() => repo = FakeEventsRepository(hosted: []));

  Future<void> pumpInvites(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(theme: AppTheme.light, home: const MyEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invites'));
    await tester.pumpAndSettle();
  }

  testWidgets("a guest's card shows the invitation the host made", (
    tester,
  ) async {
    repo.invited = [
      buildInvitedEvent(
        inviteMediaUrl: 'https://cdn.test/invite.png',
        coverUrl: 'https://cdn.test/cover.jpg',
      ),
    ];
    await pumpInvites(tester);

    expect(find.text("Rohan's Housewarming"), findsOneWidget);
    // The invitation, not the cover: it is what the invite page shows too.
    final image = tester.widget<WishtickImage>(find.byType(WishtickImage));
    expect(image.url, 'https://cdn.test/invite.png');
  });

  testWidgets('with no invitation, the cover stands in', (tester) async {
    repo.invited = [buildInvitedEvent(coverUrl: 'https://cdn.test/cover.jpg')];
    await pumpInvites(tester);

    final image = tester.widget<WishtickImage>(find.byType(WishtickImage));
    expect(image.url, 'https://cdn.test/cover.jpg');
  });

  test('the invited-event payload carries the invitation and the host', () {
    final event = InvitedEvent.fromJson({
      'id': 'evt_1',
      'title': "Rohan's Housewarming",
      'type': 'generic',
      'startsAt': '2026-09-05T14:00:00.000Z',
      'timezone': 'Asia/Kolkata',
      'coverUrl': null,
      'inviteMediaUrl': 'https://cdn.test/invite.png',
      'hostName': 'Rohan',
      'myRsvp': 'pending',
      'inviteToken': 'tok_1',
    });

    expect(event.inviteMediaUrl, 'https://cdn.test/invite.png');
    expect(event.artworkUrl, 'https://cdn.test/invite.png');
    expect(event.hostName, 'Rohan');
  });
}
