import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/router/deep_links.dart';
import 'package:wishtick_flutter/core/share/share_messages.dart' as share;
import 'package:wishtick_flutter/features/wishmates/presentation/widgets/quick_share_sheet.dart';

/// What Wishtick writes when somebody shares something out of it.
///
/// Three rules hold across every one of them, and each used to be broken
/// somewhere: one format per thing, a link that can be tapped, and the
/// sender's name in the words rather than left to the chat header.
void main() {
  final startsAt = DateTime(2026, 9, 5, 19, 20);

  group('an event', () {
    test('carries who, what, when and where, and its link', () {
      final message = share.eventInvite(
        title: 'My Birthday',
        startsAt: startsAt,
        slug: 'siya-24th',
        venue: 'My Home',
        senderName: 'Jayanth',
      );

      expect(
        message.text,
        'Jayanth has invited you to My Birthday on 5 Sep 2026 · 7:20 PM '
        'at My Home. See the invitation on Wishtick',
      );
      expect(message.url, '${AppLinks.origin}/e/siya-24th');
      expect(message.combined, '${message.text}\n${message.url}');
    });

    test('an event with no venue drops the clause, not the sentence', () {
      final message = share.eventInvite(
        title: 'My Birthday',
        startsAt: startsAt,
        slug: 's',
        senderName: 'Jayanth',
      );

      expect(message.text, contains('on 5 Sep 2026 · 7:20 PM. See'));
      expect(message.text, isNot(contains(' at ')));
    });

    test('a sender with no name still reads as a sentence', () {
      // An account can reach a share screen before filling in a name, and
      // "null has invited you" is worse than not saying.
      for (final name in [null, '', '   ']) {
        final message = share.eventInvite(
          title: 'My Birthday',
          startsAt: startsAt,
          slug: 's',
          senderName: name,
        );
        expect(message.text, startsWith("You're invited to My Birthday on "));
        expect(message.text, isNot(contains('null')));
      }
    });
  });

  group('every share', () {
    /// One of each kind, built the way the app builds them.
    final all = <String, share.ShareMessage>{
      'event': share.eventInvite(
        title: 'My Birthday',
        startsAt: startsAt,
        slug: 'e1',
        venue: 'My Home',
        senderName: 'Jayanth',
      ),
      'wishlist': share.wishlist(
        title: 'Camping gear',
        slug: 'w1',
        senderName: 'Jayanth',
      ),
      'group gift': share.groupGift(
        title: 'the camera',
        url: '${AppLinks.origin}/g/1',
        senderName: 'Jayanth',
      ),
      'memory (collecting)': share.memoryContribute(
        title: 'For Amma',
        unlockAt: startsAt,
        slug: 'm1',
        personName: 'Amma',
        senderName: 'Jayanth',
      ),
      'memory (open)': share.memoryOpened(
        title: 'For Amma',
        wishCount: 6,
        slug: 'm1',
        senderName: 'Jayanth',
      ),
      'person': share.person(handle: '@priya', senderName: 'Jayanth'),
      'join the app': share.joinWishtick(senderName: 'Jayanth'),
    };

    test('has something to tap', () {
      // Two of these used to send no link at all, leaving the reader with a
      // sentence about a thing they could not go and look at.
      all.forEach((kind, message) {
        expect(message.url, isNotEmpty, reason: kind);
        expect(message.url, startsWith('http'), reason: kind);
      });
    });

    test('says who it is from', () {
      // A forwarded message loses its chat header, and with it any idea of
      // who sent it.
      all.forEach((kind, message) {
        expect(message.text, contains('Jayanth'), reason: kind);
      });
    });

    test('puts the link on its own line so it stays tappable', () {
      all.forEach((kind, message) {
        expect(message.combined, endsWith('\n${message.url}'), reason: kind);
      });
    });

    test('never leaks a null or an empty placeholder', () {
      all.forEach((kind, message) {
        expect(message.text, isNot(contains('null')), reason: kind);
        expect(message.text.trim(), message.text, reason: kind);
        expect(message.text, isNot(contains('  ')), reason: kind);
      });
    });
  });

  group('the rest', () {
    test('a wishlist names whose it is', () {
      expect(
        share
            .wishlist(title: 'Camping gear', slug: 'w1', senderName: 'Jayanth')
            .text,
        'Take a look at Jayanth\'s wishlist "Camping gear" on Wishtick',
      );
      // Unsigned, it is still the sender's own list.
      expect(
        share.wishlist(title: 'Camping gear', slug: 'w1').text,
        'Take a look at my wishlist "Camping gear" on Wishtick',
      );
    });

    test('an opened memory counts its wishes and links to itself', () {
      final one = share.memoryOpened(
        title: 'For Amma',
        wishCount: 1,
        slug: 'm1',
        senderName: 'Jayanth',
      );
      expect(one.text, 'For Amma from Jayanth is now open — 1 wish inside.');
      expect(one.url, '${AppLinks.origin}/m/m1');

      expect(
        share
            .memoryOpened(
              title: 'For Amma',
              wishCount: 6,
              slug: 'm1',
              senderName: 'Jayanth',
            )
            .text,
        contains('6 wishes inside'),
      );
    });

    test('a person points at the app, since a profile has no public page', () {
      // `/people/:id` is an internal route, not one of the paths the app
      // claims, so a link to it would open nothing.
      final message = share.person(handle: '@priya', senderName: 'Jayanth');
      expect(message.url, AppLinks.origin);
      expect(message.text, contains('@priya'));
    });
  });

  group('the WishMates sheet says the same thing as the share screen', () {
    // An event described one way from its own screen and another way from the
    // sheet was the bug. These assert the sheet defers to the same builder.
    test('an event carries the long form from the sheet too', () {
      final target = EventShareTarget(
        eventId: 'ev_1',
        title: 'My Birthday',
        startsAt: startsAt,
        venue: 'My Home',
        slug: 'e1',
        isPublic: true,
      );

      expect(
        target.shareMessage('Jayanth'),
        share
            .eventInvite(
              title: 'My Birthday',
              startsAt: startsAt,
              slug: 'e1',
              venue: 'My Home',
              senderName: 'Jayanth',
            )
            .text,
      );
      // The date and the venue are in it, which the old short form lacked.
      expect(target.shareMessage('Jayanth'), contains('5 Sep 2026'));
      expect(target.shareMessage('Jayanth'), contains('My Home'));
      expect(target.shareMessage('Jayanth'), contains('Jayanth'));
    });

    test('a wishlist and a group gift do the same', () {
      const list = WishlistShareTarget(
        wishlistId: 'wl_1',
        title: 'Camping gear',
        slug: 'w1',
        isPublic: true,
      );
      expect(
        list.shareMessage('Jayanth'),
        share
            .wishlist(title: 'Camping gear', slug: 'w1', senderName: 'Jayanth')
            .text,
      );

      const gift = GroupGiftShareTarget(
        groupGiftId: 'g1',
        title: 'the camera',
        url: 'https://wishtick.com/g/1',
      );
      expect(
        gift.shareMessage('Jayanth'),
        share
            .groupGift(
              title: 'the camera',
              url: 'https://wishtick.com/g/1',
              senderName: 'Jayanth',
            )
            .text,
      );
    });
  });
}
