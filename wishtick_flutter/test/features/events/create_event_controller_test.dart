import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/domain/event.dart';
import 'package:wishtick_flutter/features/events/presentation/create_event_controller.dart';

import '../../helpers/events_fakes.dart';

void main() {
  late FakeEventsRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeEventsRepository();
    container = ProviderContainer(
      overrides: [eventsRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() => container.dispose());

  CreateEventController notifier() =>
      container.read(createEventProvider.notifier);
  CreateEventState state() => container.read(createEventProvider);

  void fillStep1() {
    notifier()
      ..setPersonName('Siya')
      ..setRelation('friend', 'Friend');
  }

  void fillStep2() {
    notifier()
      ..setTitle("Siya's Birthday")
      ..setDate(DateTime(2026, 7, 19))
      ..setTime(const TimeOfDayValue(20, 0))
      ..setVenue('Mysore Socials')
      ..setDescription('Join us.');
  }

  test('step 1 needs both a person and a relation', () {
    expect(state().step1Complete, isFalse);

    notifier().setPersonName('Siya');
    expect(state().step1Complete, isFalse);

    notifier().setRelation('friend', 'Friend');
    expect(state().step1Complete, isTrue);
  });

  test('every field on step 2 is required', () {
    fillStep1();
    notifier()
      ..setTitle("Siya's Birthday")
      ..setDate(DateTime(2026, 7, 19))
      ..setVenue('Mysore Socials')
      ..setDescription('Join us.');

    // A date with no time would otherwise quietly become midnight.
    expect(state().step2Complete, isFalse);
    expect(state().startsAt, isNull);

    notifier().setTime(const TimeOfDayValue(20, 0));
    expect(state().step2Complete, isTrue);
    expect(state().startsAt, DateTime(2026, 7, 19, 20, 0));
  });

  test('the suggested title is built from step 1, occasion included', () {
    fillStep1();
    expect(notifier().suggestedTitle(), "Siya's Birthday");

    notifier().setOccasion('house_warming');
    expect(notifier().suggestedTitle(), "Siya's House Warming");
  });

  test('an occasion the API has no type for still maps to one', () {
    // Eight tiles, four API types — Rakhi has to land somewhere.
    notifier().setOccasion('rakhi');
    expect(state().occasion.type, EventType.special);
  });

  test('submit sends an IANA timezone, not the platform abbreviation', () async {
    fillStep1();
    fillStep2();

    await notifier().submit();

    expect(repo.createCalls.single['timezone'], 'Asia/Kolkata');
  });

  test('submit carries person, relation and venue', () async {
    fillStep1();
    fillStep2();

    final created = await notifier().submit();

    expect(created, isNotNull);
    final call = repo.createCalls.single;
    expect(call['personName'], 'Siya');
    expect(call['relation'], 'friend');
    expect(call['venue'], 'Mysore Socials');
    expect(call['type'], EventType.birthday);
  });

  test('an incomplete step 2 never reaches the server', () async {
    fillStep1();
    expect(await notifier().submit(), isNull);
    expect(repo.createCalls, isEmpty);
  });

  test('a past date is explained in the words the picker used', () async {
    fillStep1();
    fillStep2();
    repo.failure = const ApiException(
      code: 'VALIDATION_FAILED',
      message: 'startsAt must be in the future',
      statusCode: 400,
    );

    expect(await notifier().submit(), isNull);
    expect(state().error, contains('has to be in the future'));
    expect(state().busy, isFalse);
  });
}
