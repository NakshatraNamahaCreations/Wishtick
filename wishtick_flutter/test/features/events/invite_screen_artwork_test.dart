import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/media/media_repository.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_image.dart';
import 'package:wishtick_flutter/features/events/data/invite_repository.dart';
import 'package:wishtick_flutter/features/events/domain/public_invite.dart';
import 'package:wishtick_flutter/features/events/presentation/invite_screen.dart';

import '../../helpers/gifting_fakes.dart';

/// The guest's invitation, opened by token.
///
/// It drew `coverUrl` and nothing else, so every event made in the app — which
/// carries an invitation and never a cover — showed a page with no artwork at
/// all. The venue had the same shape of bug: the server sends it, this screen
/// was not reading it, and an invitation told a guest a time and no place.
void main() {
  late FakeInviteRepository repo;

  setUp(() => repo = FakeInviteRepository());

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 1600)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [inviteRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const InviteScreen(token: 'tok_1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the invitation the host made, whole', (tester) async {
    repo.invite = buildInvite(
      inviteMediaUrl: 'https://cdn.test/invite.png',
      coverUrl: 'https://cdn.test/cover.jpg',
    );
    await pump(tester);

    final image = tester.widget<WishtickImage>(find.byType(WishtickImage));
    // The invitation, not the cover — it is the point of this screen.
    expect(image.url, 'https://cdn.test/invite.png');
    // Whole: a fixed 3:4 box cropped the last line off other shapes.
    expect(image.fit, BoxFit.fitWidth);
    expect(
      find.ancestor(
        of: find.byType(WishtickImage),
        matching: find.byType(AspectRatio),
      ),
      findsNothing,
    );
  });

  testWidgets('an invitation that cannot be drawn falls back to the cover', (
    tester,
  ) async {
    repo.invite = buildInvite(
      inviteMediaUrl: 'https://cdn.test/invite.pdf',
      coverUrl: 'https://cdn.test/cover.jpg',
    );
    await pump(tester);

    final image = tester.widget<WishtickImage>(find.byType(WishtickImage));
    expect(image.url, 'https://cdn.test/cover.jpg');
  });

  testWidgets('with neither, no artwork is drawn at all', (tester) async {
    repo.invite = buildInvite();
    await pump(tester);

    expect(find.byType(WishtickImage), findsNothing);
  });

  testWidgets('the invitation says where, not only when', (tester) async {
    repo.invite = buildInvite(venue: 'Mysore Socials');
    await pump(tester);

    expect(find.text('Mysore Socials'), findsOneWidget);
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
  });

  testWidgets('an event with no venue omits the line rather than blanking it', (
    tester,
  ) async {
    repo.invite = buildInvite();
    await pump(tester);

    expect(find.byIcon(Icons.place_outlined), findsNothing);
    // The time is always there, so the block never collapses to nothing.
    expect(find.byIcon(Icons.schedule), findsOneWidget);
  });

  group('the wire payload', () {
    // The widget tests above build the model directly, so on their own they
    // would pass even if these fields were never parsed — which is the exact
    // bug being fixed here. This is what pins the field names.
    Map<String, dynamic> payload({
      String? venue = 'Mysore Socials',
      String? inviteMediaUrl = 'https://cdn.test/invite.png',
    }) => {
      'title': "Siya's 24th",
      'type': 'birthday',
      'startsAt': '2026-09-05T14:00:00.000Z',
      'endsAt': null,
      'timezone': 'Asia/Kolkata',
      'description': 'Join us.',
      'coverUrl': 'https://cdn.test/cover.jpg',
      'venue': venue,
      'inviteMediaUrl': inviteMediaUrl,
      'status': 'published',
    };

    test('carries the invitation and the venue the server sends', () {
      final event = InviteEvent.fromJson(payload());

      expect(event.inviteMediaUrl, 'https://cdn.test/invite.png');
      expect(event.venue, 'Mysore Socials');
      // The invitation wins over the cover.
      expect(event.artworkUrl, 'https://cdn.test/invite.png');
    });

    test('falls back to the cover, then to nothing', () {
      expect(
        InviteEvent.fromJson(payload(inviteMediaUrl: null)).artworkUrl,
        'https://cdn.test/cover.jpg',
      );
      expect(
        InviteEvent.fromJson({
          ...payload(inviteMediaUrl: null),
          'coverUrl': null,
        }).artworkUrl,
        isNull,
      );
    });

    test('an older event with neither field still parses', () {
      // Both are optional on the wire; an invitation written before they
      // existed must not throw on the guest's phone.
      final event = InviteEvent.fromJson({
        'title': 'Old party',
        'type': 'generic',
        'startsAt': '2026-09-05T14:00:00.000Z',
        'timezone': 'Asia/Kolkata',
        'status': 'published',
      });

      expect(event.venue, isNull);
      expect(event.inviteMediaUrl, isNull);
      expect(event.artworkUrl, isNull);
    });
  });

  group('what can be drawn inline', () {
    test('stills and GIFs can; video and documents cannot', () {
      for (final drawable in [
        'invite.png',
        'INVITE.PNG',
        'https://cdn.test/a/b/card.jpeg',
        'card.webp',
        'card.heic',
        'party.gif',
      ]) {
        expect(
          MediaRepository.isDrawableImage(drawable),
          isTrue,
          reason: drawable,
        );
      }
      for (final not in ['invite.pdf', 'clip.mp4', 'clip.mov', 'note.m4a']) {
        expect(MediaRepository.isDrawableImage(not), isFalse, reason: not);
      }
    });

    test('a signed URL is judged on its path, not its signature', () {
      // The query string ends the address, so testing the whole thing would
      // call every signed image undrawable and blank out real artwork.
      expect(
        MediaRepository.isDrawableImage(
          'https://cdn.test/invite.png?X-Amz-Signature=abc123&expires=99',
        ),
        isTrue,
      );
      expect(
        MediaRepository.isDrawableImage('https://cdn.test/invite.pdf?sig=abc'),
        isFalse,
      );
    });

    test('an extensionless URL is drawn rather than hidden', () {
      // Most CDN and proxy addresses look like this. The image widget falls
      // back to its own placeholder if the bytes are not an image; an
      // allowlist here would hide real photos behind one.
      expect(
        MediaRepository.isDrawableImage('https://cdn.test/media/abc123'),
        isTrue,
      );
    });
  });
}
