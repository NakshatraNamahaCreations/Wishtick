import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/media/media_repository.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/auth/presentation/session_controller.dart';
import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/domain/event.dart';
import 'package:wishtick_flutter/features/events/presentation/create_event_controller.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/events_fakes.dart';
import '../../helpers/wishlist_fakes.dart';

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
  late FakeEventsRepository repo;
  late FakeMediaRepository media;
  late ProviderContainer container;

  /// Stands in for the designer's PNG; the bytes are never decoded here.
  final card = Uint8List.fromList([1, 2, 3]);

  setUp(() {
    repo = FakeEventsRepository();
    media = FakeMediaRepository();
    container = ProviderContainer(
      overrides: [
        eventsRepositoryProvider.overrideWithValue(repo),
        mediaRepositoryProvider.overrideWithValue(media),
      ],
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

  group('publish — the one call that makes the event exist', () {
    // Nothing reaches the server before this: the person, the details and
    // the card all wait in the state until the host has seen the preview.

    test('uploads the card, creates with its id, then publishes', () async {
      fillStep1();
      fillStep2();
      notifier().setInvitation(card, 'invitation.png');

      final event = await notifier().publish();

      expect(event, isNotNull);
      expect(media.uploadCalls, [MediaPurpose.eventInvite]);
      // The name travels separately — XFile.fromData drops it on io.
      expect(media.uploadedNames, ['invitation.png']);
      expect(repo.createCalls.single['inviteMediaId'], 'media_1');
      expect(repo.publishCalls, ['evt_1']);
    });

    test('sends an IANA timezone, not the platform abbreviation', () async {
      fillStep1();
      fillStep2();

      await notifier().publish();

      expect(repo.createCalls.single['timezone'], 'Asia/Kolkata');
    });

    test('carries person, relation and venue', () async {
      fillStep1();
      fillStep2();

      final created = await notifier().publish();

      expect(created, isNotNull);
      final call = repo.createCalls.single;
      expect(call['personName'], 'Siya');
      expect(call['relation'], 'friend');
      expect(call['venue'], 'Mysore Socials');
      expect(call['type'], EventType.birthday);
    });

    test('an incomplete step 2 never reaches the server', () async {
      fillStep1();
      expect(await notifier().publish(), isNull);
      expect(repo.createCalls, isEmpty);
      expect(media.uploadCalls, isEmpty);
    });

    test(
      'the event is created invite-only, so its link admits people',
      () async {
        // The server defaults to private, whose link 404s for everybody — and
        // the share screen this flow ends on hands that link out.
        fillStep1();
        fillStep2();

        await notifier().publish();

        expect(
          repo.createCalls.single['visibility'],
          EventVisibility.inviteOnly,
        );
      },
    );

    test('no invitation means no upload, and an event with no card', () async {
      fillStep1();
      fillStep2();

      await notifier().publish();

      expect(media.uploadCalls, isEmpty);
      expect(repo.createCalls.single['inviteMediaId'], isNull);
      expect(repo.publishCalls, ['evt_1']);
    });

    test(
      'a wishlist made on the way is linked as the event is created',
      () async {
        fillStep1();
        fillStep2();

        await notifier().publish(wishlistId: 'wl_9');

        expect(repo.createCalls.single['wishlistIds'], ['wl_9']);
      },
    );

    test(
      'a retry after a failed publish does not create a second event',
      () async {
        fillStep1();
        fillStep2();
        notifier().setInvitation(card, 'invitation.png');
        repo.publishFailure = const ApiException(
          code: 'EVENT_DATE_IN_PAST',
          message: 'Move the event to a future date',
          statusCode: 400,
        );

        expect(await notifier().publish(), isNull);
        expect(state().error, contains('has to be in the future'));
        expect(state().busy, isFalse);
        expect(repo.createCalls, hasLength(1));

        repo.publishFailure = null;
        final event = await notifier().publish();

        expect(event, isNotNull);
        // Same event, same upload: neither step is repeated.
        expect(repo.createCalls, hasLength(1));
        expect(media.uploadCalls, hasLength(1));
        expect(repo.publishCalls, ['evt_1']);
      },
    );

    test(
      'a retry after a failed create does not upload the card again',
      () async {
        fillStep1();
        fillStep2();
        notifier().setInvitation(card, 'invitation.png');
        repo.failure = const ApiException(
          code: 'EVENT_LIMIT_REACHED',
          message: 'limit',
          statusCode: 409,
        );

        expect(await notifier().publish(), isNull);
        expect(state().error, contains('as many events'));
        expect(media.uploadCalls, hasLength(1));
        expect(repo.createCalls, isEmpty);

        repo.failure = null;
        await notifier().publish();

        expect(media.uploadCalls, hasLength(1));
        expect(repo.createCalls.single['inviteMediaId'], 'media_1');
      },
    );

    test('a new design replaces the old one, upload and all', () async {
      fillStep1();
      fillStep2();
      notifier().setInvitation(card, 'invitation.png');
      repo.failure = const ApiException(
        code: 'EVENT_LIMIT_REACHED',
        message: 'limit',
        statusCode: 409,
      );
      await notifier().publish();
      expect(state().inviteMediaId, 'media_1');

      // Back to the designer, and out again with a different card.
      notifier().setInvitation(Uint8List.fromList([9]), 'party.gif');

      expect(state().invitation?.fileName, 'party.gif');
      // The old upload is forgotten, or the old card would be attached.
      expect(state().inviteMediaId, isNull);

      repo.failure = null;
      await notifier().publish();

      expect(media.uploadedNames, ['invitation.png', 'party.gif']);
      expect(repo.createCalls.single['inviteMediaId'], 'media_2');
    });

    test('a past date is explained in the words the picker used', () async {
      fillStep1();
      fillStep2();
      repo.failure = const ApiException(
        code: 'VALIDATION_FAILED',
        message: 'startsAt must be in the future',
        statusCode: 400,
      );

      expect(await notifier().publish(), isNull);
      expect(state().error, contains('has to be in the future'));
      expect(state().busy, isFalse);
    });

    test('reset returns the wizard to blank', () {
      fillStep1();
      fillStep2();
      notifier().setInvitation(card, 'invitation.png');

      notifier().reset();

      expect(state().step1Complete, isFalse);
      expect(state().title, isEmpty);
      expect(state().invitation, isNull);
      expect(state().created, isNull);
    });
  });

  group('who the event is for', () {
    test('picking a WishMate links the name to an account', () {
      final n = notifier();

      n.setWishmate(userId: 'u_9', name: 'Rohan Prasad');

      expect(state().personName, 'Rohan Prasad');
      expect(state().wishmateId, 'u_9');
      expect(state().linkedToWishmate, isTrue);
    });

    test('typing over a picked name breaks the link', () {
      final n = notifier();
      n.setWishmate(userId: 'u_9', name: 'Rohan Prasad');

      n.setPersonName('Rohan P');

      // The name no longer refers to the account that was chosen, so treating
      // it as one would submit an event linked to the wrong person.
      expect(state().linkedToWishmate, isFalse);
    });

    test('losing the link clears a relation that link allowed', () {
      final n = notifier();
      n.setWishmate(userId: 'u_9', name: 'Rohan Prasad');
      n.setRelation('colleagues_manager', 'Manager');

      n.setPersonName('Rohan P');

      // Otherwise the draft carries a relation the picker would no longer
      // offer, and nothing on screen says so.
      expect(state().relationKey, isNull);
      expect(state().relationLabel, isNull);
    });

    test('losing the link keeps a relation that is open to everyone', () {
      final n = notifier();
      n.setWishmate(userId: 'u_9', name: 'Meera');
      n.setRelation('parents_mother', 'Mother');

      n.setPersonName('Meer');

      // Parents survive: they are choosable without an account either way, so
      // clearing this would be gratuitous.
      expect(state().relationKey, 'parents_mother');
    });

    test('the open groups are parents and kids, and nothing else', () {
      // The whole restriction rests on this set; a stray group here silently
      // widens what an un-invited person can be.
      expect(CreateEventState.openRelationGroups, {'parents', 'kids'});

      expect(
        CreateEventState.isRelationOpenToEveryone('parents_father'),
        isTrue,
      );
      expect(CreateEventState.isRelationOpenToEveryone('kids_son'), isTrue);
      for (final key in const [
        'partner_wife',
        'friends_best_friend',
        'siblings_brother',
        'colleagues_manager',
      ]) {
        expect(
          CreateEventState.isRelationOpenToEveryone(key),
          isFalse,
          reason: '$key should need an invite',
        );
      }
      expect(CreateEventState.isRelationOpenToEveryone(null), isFalse);
    });
  });

  group('an event for the host themself', () {
    test('needs no name and no relation to finish step 1', () {
      notifier().setForSelf(true);

      // A relation to yourself is not a thing, and the name is the account's.
      expect(state().step1Complete, isTrue);
      expect(state().forSelf, isTrue);
    });

    test(
      'switching to "me" clears a name, link and relation already typed',
      () {
        notifier()
          ..setWishmate(userId: 'u_9', name: 'Rohan')
          ..setRelation('friends_friend', 'Friend');

        notifier().setForSelf(true);

        // Left in the draft they would be submitted as a person and a relation
        // for an event that has neither.
        expect(state().personName, isEmpty);
        expect(state().wishmateId, isNull);
        expect(state().relationKey, isNull);
      },
    );

    test('switching back to "someone else" makes step 1 incomplete again', () {
      notifier().setForSelf(true);
      notifier().setForSelf(false);

      expect(state().step1Complete, isFalse);
    });

    test('submits the flag and sends no person or relation', () async {
      notifier()
        ..setForSelf(true)
        ..setOccasion('birthday');
      fillStep2();

      await notifier().publish();

      final call = repo.createCalls.single;
      expect(call['forSelf'], isTrue);
      // Null, not '' — the server would store an empty name as an answer.
      expect(call['personName'], isNull);
      expect(call['relation'], isNull);
    });

    test('a normal event submits forSelf false', () async {
      fillStep1();
      fillStep2();

      await notifier().publish();

      expect(repo.createCalls.single['forSelf'], isFalse);
      expect(repo.createCalls.single['personName'], 'Siya');
    });

    test('the suggested title names the host, so guests can read it', () {
      // "My Birthday" on someone else's phone invites nobody. With a name on
      // the account, the title is theirs.
      final signedIn = ProviderContainer(
        overrides: [
          eventsRepositoryProvider.overrideWithValue(repo),
          sessionProvider.overrideWith(() => _SignedIn('Siya')),
        ],
      );
      addTearDown(signedIn.dispose);
      signedIn.read(createEventProvider.notifier)
        ..setForSelf(true)
        ..setOccasion('birthday');

      expect(
        signedIn.read(createEventProvider.notifier).suggestedTitle(),
        "Siya's Birthday",
      );
    });

    test('falls back to "My" when the account has no name', () {
      // The default container has no session at all.
      notifier()
        ..setForSelf(true)
        ..setOccasion('birthday');

      expect(notifier().suggestedTitle(), 'My Birthday');
    });
  });
}
