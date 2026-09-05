import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_image.dart';
import 'package:wishtick_flutter/features/home/domain/wishtick_event.dart';
import 'package:wishtick_flutter/features/home/presentation/widgets/home_cards.dart';

import '../../helpers/home_fakes.dart';

/// The "Upcoming Events" rail draws the invitation the host made, not only
/// the cover — an event made in the app has the former and never the latter.
void main() {
  const payload = {
    'id': 'evt_1',
    'title': "Rohan's Housewarming",
    'type': 'generic',
    'startsAt': '2026-09-05T14:00:00.000Z',
    'timezone': 'Asia/Kolkata',
    'coverUrl': 'https://cdn.test/cover.jpg',
    'inviteMediaUrl': 'https://cdn.test/invite.png',
  };

  test('both payloads carry the invitation, and it comes before the cover', () {
    final invited = WishtickEvent.fromInvited(payload);
    final hosted = WishtickEvent.fromHosted(payload);

    expect(invited.inviteMediaUrl, 'https://cdn.test/invite.png');
    expect(invited.artworkUrl, 'https://cdn.test/invite.png');
    expect(hosted.artworkUrl, 'https://cdn.test/invite.png');
    // With no card, the cover; with neither, nothing to draw.
    expect(
      WishtickEvent.fromInvited({
        ...payload,
        'inviteMediaUrl': null,
      }).artworkUrl,
      'https://cdn.test/cover.jpg',
    );
    expect(
      WishtickEvent.fromInvited({
        ...payload,
        'inviteMediaUrl': null,
        'coverUrl': null,
      }).artworkUrl,
      isNull,
    );
  });

  testWidgets('the rail card draws the invitation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 240,
            child: HomeEventCard(
              event: buildEvent(
                inviteMediaUrl: 'https://cdn.test/invite.png',
                coverUrl: 'https://cdn.test/cover.jpg',
              ),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<WishtickImage>(find.byType(WishtickImage));
    expect(image.url, 'https://cdn.test/invite.png');
  });
}
