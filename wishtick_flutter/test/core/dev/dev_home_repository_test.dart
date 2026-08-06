import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/core/dev/dev_home_repositories.dart';
import 'package:wishtick_flutter/core/dev/dev_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefsWith({List<String> dates = const []}) async {
    SharedPreferences.setMockInitialValues({
      if (dates.isNotEmpty) DevKeys.dates: dates,
    });
    return SharedPreferences.getInstance();
  }

  /// A saved important date whose month/day is [daysFromNow] away, stored with
  /// a 1999 year so the age is meaningful.
  String savedDate({
    required int daysFromNow,
    String personName = 'Siya',
    String id = 'd1',
  }) {
    final when = DateTime.now().toUtc().add(Duration(days: daysFromNow));
    final month = when.month.toString().padLeft(2, '0');
    final day = when.day.toString().padLeft(2, '0');
    return jsonEncode({
      'id': id,
      'personName': personName,
      'relation': 'Best Friend',
      'occasionKey': 'birthday',
      'date': '1999-$month-$day',
    });
  }

  group('addresses', () {
    test('the first saved address becomes the default', () async {
      final repo = DevHomeRepository(await prefsWith());

      final created = await repo.createAddress(
        label: 'Home',
        recipientName: 'Ananya',
        phone: '+919876543210',
        line1: 'D-Block',
        city: 'Mysuru',
        state: 'Karnataka',
        pincode: '570031',
      );

      expect(created.isDefault, isTrue);
      expect(created.country, 'India');
    });

    test('promoting one demotes the incumbent', () async {
      final repo = DevHomeRepository(await prefsWith());
      await repo.createAddress(
        label: 'Home',
        recipientName: 'A',
        phone: '1',
        line1: 'L1',
        city: 'Mysuru',
        state: 'KA',
        pincode: '570031',
      );
      final second = await repo.createAddress(
        label: 'Work',
        recipientName: 'A',
        phone: '1',
        line1: 'L1',
        city: 'Mysuru',
        state: 'KA',
        pincode: '570031',
      );
      expect(second.isDefault, isFalse);

      await repo.updateAddress(second.id, isDefault: true);

      final all = await repo.listAddresses();
      expect(all.where((a) => a.isDefault), hasLength(1));
      // Default sorts first.
      expect(all.first.label, 'Work');
    });

    test('refuses to clear the only default', () async {
      final repo = DevHomeRepository(await prefsWith());
      final only = await repo.createAddress(
        label: 'Home',
        recipientName: 'A',
        phone: '1',
        line1: 'L1',
        city: 'Mysuru',
        state: 'KA',
        pincode: '570031',
      );

      expect(
        () => repo.updateAddress(only.id, isDefault: false),
        throwsA(isA<StateError>()),
      );
    });

    test('removing the default promotes the next-oldest', () async {
      final repo = DevHomeRepository(await prefsWith());
      final first = await repo.createAddress(
        label: 'Home',
        recipientName: 'A',
        phone: '1',
        line1: 'L1',
        city: 'Mysuru',
        state: 'KA',
        pincode: '570031',
      );
      await repo.createAddress(
        label: 'Work',
        recipientName: 'A',
        phone: '1',
        line1: 'L1',
        city: 'Mysuru',
        state: 'KA',
        pincode: '570031',
      );

      await repo.removeAddress(first.id);

      final all = await repo.listAddresses();
      expect(all, hasLength(1));
      expect(all.single.label, 'Work');
      expect(all.single.isDefault, isTrue);
    });

    test('survives a restart, so Home still knows where to deliver', () async {
      final prefs = await prefsWith();
      await DevHomeRepository(prefs).createAddress(
        label: 'Home',
        recipientName: 'A',
        phone: '1',
        line1: 'L1',
        city: 'Mysuru',
        state: 'KA',
        pincode: '570031',
      );

      // A fresh instance over the same prefs is what a relaunch looks like.
      final restarted = await DevHomeRepository(prefs).listAddresses();

      expect(restarted, hasLength(1));
      expect(restarted.single.label, 'Home');
    });
  });

  group('upcoming occasions', () {
    test('reads the dates onboarding saved', () async {
      final repo = DevHomeRepository(
        await prefsWith(dates: [savedDate(daysFromNow: 3)]),
      );

      final upcoming = await repo.upcomingOccasions();

      expect(upcoming, hasLength(1));
      expect(upcoming.single.personName, 'Siya');
      expect(upcoming.single.daysAway, 3);
      expect(upcoming.single.turningAge, greaterThan(20));
    });

    test('honours withinDays', () async {
      final repo = DevHomeRepository(
        await prefsWith(
          dates: [
            savedDate(daysFromNow: 5, personName: 'Soon', id: 'a'),
            savedDate(daysFromNow: 50, personName: 'Later', id: 'b'),
          ],
        ),
      );

      expect(
        (await repo.upcomingOccasions(withinDays: 30)).map((o) => o.personName),
        ['Soon'],
      );
      expect(
        (await repo.upcomingOccasions(withinDays: 90)).map((o) => o.personName),
        ['Soon', 'Later'],
      );
    });

    test('sorts soonest first', () async {
      final repo = DevHomeRepository(
        await prefsWith(
          dates: [
            savedDate(daysFromNow: 20, personName: 'Third', id: 'c'),
            savedDate(daysFromNow: 2, personName: 'First', id: 'a'),
            savedDate(daysFromNow: 10, personName: 'Second', id: 'b'),
          ],
        ),
      );

      expect(
        (await repo.upcomingOccasions(withinDays: 60)).map((o) => o.personName),
        ['First', 'Second', 'Third'],
      );
    });
  });

  group('discover', () {
    test('builds a person shelf from a saved date', () async {
      final home = DevHomeRepository(
        await prefsWith(dates: [savedDate(daysFromNow: 3)]),
      );

      final feed = await DevDiscoverRepository(home).feed();

      final person = feed.sections.firstWhere(
        (s) => s.person != null,
        orElse: () => throw StateError('no person shelf'),
      );
      expect(person.title, "Gift suggestions for Siya's Birthday");
      expect(person.person?.name, 'Siya');
    });

    test(
      'still serves the price and premium shelves with no saved dates',
      () async {
        final home = DevHomeRepository(await prefsWith());

        final feed = await DevDiscoverRepository(home).feed();

        expect(feed.sections.any((s) => s.person != null), isFalse);
        expect(feed.sections, isNotEmpty);
        // Every shelf that survives has something to show.
        for (final section in feed.sections) {
          expect(section.items, isNotEmpty);
        }
      },
    );
  });
}
