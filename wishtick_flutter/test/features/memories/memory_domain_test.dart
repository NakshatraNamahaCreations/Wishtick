import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/memories/domain/memory.dart';

import '../../helpers/memory_fakes.dart';

void main() {
  group('MemoryCapsule', () {
    test(
      'an empty wish list on a sealed capsule is the lock, not emptiness',
      () {
        // The server withholds content until it opens, so `wishes` being empty
        // while `wishCount` is 4 is exactly what a sealed capsule looks like.
        final sealed = buildCapsule(
          status: MemoryStatus.collecting,
          wishCount: 4,
        );

        expect(sealed.isOpen, isFalse);
        expect(sealed.wishes, isEmpty);
        expect(sealed.wishCount, 4);
      },
    );

    test('the countdown counts down in the largest unit that fits', () {
      final days = buildCapsule(
        unlockAt: DateTime.now().add(const Duration(days: 5, hours: 3)),
      );
      expect(days.countdownLabel, 'Unlocks in 5 days');

      final oneDay = buildCapsule(
        unlockAt: DateTime.now().add(const Duration(days: 1, minutes: 5)),
      );
      expect(oneDay.countdownLabel, 'Unlocks in 1 day');

      final hours = buildCapsule(
        unlockAt: DateTime.now().add(const Duration(hours: 4)),
      );
      expect(hours.countdownLabel, 'Unlocks in 4 hours');

      final minutes = buildCapsule(
        unlockAt: DateTime.now().add(const Duration(minutes: 20)),
      );
      expect(minutes.countdownLabel, 'Unlocks in 20 min');
    });

    test('the clock passing is not the same as being open', () {
      // The unlock job flips the status. Until it runs, a capsule whose instant
      // has passed is still sealed — and must not claim to be open.
      final overdue = buildCapsule(
        status: MemoryStatus.collecting,
        unlockAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(overdue.untilUnlock.isNegative, isTrue);
      expect(overdue.isOpen, isFalse);
      expect(overdue.countdownLabel, 'Unlocking…');
    });

    test('an opened capsule says so', () {
      final open = buildCapsule(
        status: MemoryStatus.unlocked,
        wishCount: 1,
        wishes: [buildWish(id: 'w1', contributorName: 'Priya Shah')],
      );

      expect(open.isOpen, isTrue);
      expect(open.countdownLabel, 'Unlocked');
      expect(open.wishes, hasLength(1));
    });

    test('parses a capsule off the wire, wishes and all', () {
      final capsule = MemoryCapsule.fromJson({
        'id': 'mem_1',
        'title': "Mridula's Birthday",
        'personName': 'Mridula',
        'occasion': 'birthday',
        'status': 'unlocked',
        'unlockAt': '2026-07-19T18:30:00.000Z',
        'timezone': 'Asia/Kolkata',
        'wishCount': 1,
        'contributors': ['Priya'],
        'hostId': 'user_1',
        'isHost': true,
        'includeYear': false,
        'createdAt': '2026-07-01T00:00:00.000Z',
        'wishes': [
          {
            'id': 'w1',
            'contributorName': 'Priya Shah',
            'kind': 'audio',
            'text': null,
            'mediaUrl': 'https://cdn.test/a.m4a',
            'durationMs': 20_000,
            'reactionCount': 2,
            'createdAt': '2026-07-02T00:00:00.000Z',
          },
        ],
      });

      expect(capsule.isOpen, isTrue);
      expect(capsule.wishes.single.kind, MemoryWishKind.audio);
      expect(capsule.wishes.single.duration, const Duration(seconds: 20));
      expect(capsule.contributors, ['Priya']);
    });

    test('an unknown wish kind degrades to text rather than throwing', () {
      // A newer server shipping a kind this build has never heard of must not
      // crash the story.
      final wish = MemoryWish.fromJson({
        'id': 'w1',
        'contributorName': 'Priya',
        'kind': 'hologram',
        'createdAt': '2026-07-02T00:00:00.000Z',
      });

      expect(wish.kind, MemoryWishKind.text);
    });
  });

  group('MemoryWishKind', () {
    test('only text carries no file', () {
      expect(MemoryWishKind.text.needsMedia, isFalse);
      expect(MemoryWishKind.photo.needsMedia, isTrue);
      expect(MemoryWishKind.audio.needsMedia, isTrue);
      expect(MemoryWishKind.video.needsMedia, isTrue);
    });

    test('each kind names its own compose screen', () {
      expect(MemoryWishKind.photo.label, 'Photo Message');
      expect(MemoryWishKind.text.label, 'Write Message');
      expect(MemoryWishKind.video.label, 'Video Message');
      expect(MemoryWishKind.audio.label, 'Voice Note');
    });
  });
}
