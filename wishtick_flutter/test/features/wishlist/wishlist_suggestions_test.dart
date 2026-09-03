import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/onboarding/domain/onboarding_options.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/wishlist_suggestions.dart';

import '../../helpers/wishmates_fakes.dart';

/// The two pure halves of the Create Wishlist suggestions.
void main() {
  final mates = [
    buildWishmate(userId: 'u_1', displayName: 'Siya Kapoor'),
    buildWishmate(userId: 'u_2', displayName: 'Priyal Sharma'),
    buildWishmate(userId: 'u_3', displayName: 'Rohan Prasad'),
  ];

  group('matchingWishmates', () {
    test('matches the start of any word of the name, case-folded', () {
      expect(matchingWishmates(mates, 'si').map((m) => m.userId), ['u_1']);
      // "sh" is the start of Sharma, not of Priyal.
      expect(matchingWishmates(mates, 'SH').map((m) => m.userId), ['u_2']);
    });

    test('does not match the middle of a word', () {
      // "iya" is inside both Siya and Priyal; neither starts a word with it.
      expect(matchingWishmates(mates, 'iya'), isEmpty);
    });

    // A wall of every friend under an empty field is a directory, not a hint.
    test('offers nobody for an empty field', () {
      expect(matchingWishmates(mates, ''), isEmpty);
      expect(matchingWishmates(mates, '   '), isEmpty);
    });

    test('caps the strip at six', () {
      final many = [
        for (var i = 0; i < 10; i++)
          buildWishmate(userId: 'u_$i', displayName: 'Sam $i'),
      ];
      expect(matchingWishmates(many, 's'), hasLength(6));
    });
  });

  group('occasionSuggestions', () {
    const taxonomy = {
      'birthday': 'Birthday',
      'anniversary': 'Anniversary',
      'wedding': 'Wedding',
    };
    final dates = [
      ImportantDate(
        id: 'd_1',
        personName: 'Siya',
        relation: 'friend',
        occasionKey: 'birthday',
        date: '2026-09-01',
      ),
    ];

    // Only while typing, like the name field: an empty occasion offers
    // nothing rather than a standing block of every occasion there is.
    test('offers nothing for an empty field', () {
      expect(
        occasionSuggestions(dates: dates, taxonomy: taxonomy, typed: ''),
        isEmpty,
      );
    });

    test('the person s own dates come first, worded as a list name', () {
      final out = occasionSuggestions(
        dates: dates,
        taxonomy: taxonomy,
        typed: 'birth',
      );
      expect(out, ["Siya's Birthday", 'Birthday']);
    });

    test('typing narrows to what contains it', () {
      final out = occasionSuggestions(
        dates: dates,
        taxonomy: taxonomy,
        typed: 'wed',
      );
      expect(out, ['Wedding']);
    });

    test('a date whose occasion is not in the taxonomy still shows', () {
      final out = occasionSuggestions(
        dates: [
          ImportantDate(
            id: 'd_2',
            personName: 'Ma',
            relation: 'mother',
            occasionKey: 'retirement',
            date: '2026-09-01',
          ),
        ],
        taxonomy: taxonomy,
        typed: 'retire',
      );
      expect(out.first, "Ma's retirement");
    });

    test('never repeats a label', () {
      final out = occasionSuggestions(
        dates: [...dates, ...dates],
        taxonomy: taxonomy,
        typed: 'birth',
      );
      expect(out.where((l) => l == "Siya's Birthday"), hasLength(1));
    });
  });
}
