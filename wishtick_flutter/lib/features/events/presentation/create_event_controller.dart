import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// For XFile, which MediaRepository takes. cross_file is not a direct
// dependency; image_picker re-exports it and is.
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';

/// The occasion tiles on `257:733`, mapped to the event types the API takes.
///
/// The grid shows eight occasions but the API has four types, so several
/// occasions share one — the `occasionKey` keeps the distinction the tile made.
const kEventOccasions = <({String key, String label, EventType type})>[
  (key: 'birthday', label: 'Birthday', type: EventType.birthday),
  (key: 'anniversary', label: 'Anniversary', type: EventType.anniversary),
  (key: 'wedding', label: 'Wedding', type: EventType.special),
  (key: 'house_warming', label: 'House Warming', type: EventType.special),
  (key: 'mom_to_be', label: 'Mom to Be', type: EventType.special),
  (key: 'custom', label: 'Custom Events', type: EventType.generic),
  (key: 'rakhi', label: 'Rakhi', type: EventType.special),
  (key: 'best_wishes', label: 'Best Wishes', type: EventType.generic),
];

/// The zone an event is created in.
///
/// The server requires an **IANA** zone (`Asia/Kolkata`) and rejects anything
/// it cannot resolve. Dart cannot report one: `DateTime.now().timeZoneName`
/// gives the platform's abbreviation — `IST`, `GMT+05:30` — which fails that
/// check outright. Until a zone lands on the profile, this constant is the
/// honest answer, and it matches the fallback the home feed already uses.
const kDefaultTimezone = 'Asia/Kolkata';

/// The invitation the host designed or picked, held until the event exists.
///
/// Bytes rather than a file: the designer produces a PNG in memory, and the
/// upload screen already reads its pick into memory to enforce the size cap,
/// so this is what both naturally have — and what the preview draws.
@immutable
class PendingInvitation {
  const PendingInvitation({required this.bytes, required this.fileName});

  final Uint8List bytes;

  /// The name the upload is made under. `XFile.fromData` drops its `name` on
  /// io, so without this an MP4 or a PDF would go up as a JPEG.
  final String fileName;
}

/// The draft an event is composed from, across the create steps.
///
/// Everything — the person, the details, the invitation — stays here until
/// [CreateEventController.publish]. Nothing exists on the server before that,
/// so a host who backs out at any step has made nothing to clean up.
@immutable
class CreateEventState {
  const CreateEventState({
    this.personName = '',
    this.forSelf = false,
    this.wishmateId,
    this.relationKey,
    this.relationLabel,
    this.occasionKey = 'birthday',
    this.title = '',
    this.date,
    this.time,
    this.venue = '',
    this.description = '',
    this.invitation,
    this.inviteMediaId,
    this.created,
    this.error,
    this.busy = false,
  });

  // Step 1 (`257:733`)
  final String personName;

  /// The host is the one being celebrated — their own birthday or wedding.
  ///
  /// When set, step 1 asks for no name and no relation: the person is the
  /// signed-in user, and a relation to yourself is not a thing. The WishMate
  /// link is moot for the same reason.
  final bool forSelf;

  /// Set only when the name was picked from the host's WishMates.
  ///
  /// What it gates is the relation list: a person already on Wishtick can be
  /// any relation, while someone typed in by hand can only be a parent or a
  /// child — see [linkedToWishmate].
  final String? wishmateId;

  /// Whether the person named is a WishMate rather than free text.
  bool get linkedToWishmate => wishmateId != null;

  /// The relation groups open to someone who is *not* on Wishtick.
  ///
  /// Parents and children only. The reasoning is about who realistically joins
  /// an app: a partner, a friend, a sibling or a colleague can be invited and
  /// will have their own wishlist, so an event for them should hang off a real
  /// WishMate rather than a name typed once. Parents and young children are
  /// the two groups a host routinely celebrates without them ever signing up.
  ///
  /// Held here rather than in the picker so the rule that *disables* a row and
  /// the rule that *clears* a stale selection cannot drift apart.
  static const openRelationGroups = {'parents', 'kids'};

  /// Whether [relationKey] survives losing the WishMate link.
  ///
  /// Keys are group-prefixed by the seed (`parents_mother`, `kids_son`), which
  /// is what makes this a prefix test rather than a lookup against a taxonomy
  /// this class would otherwise have to load.
  static bool isRelationOpenToEveryone(String? relationKey) =>
      relationKey != null &&
      openRelationGroups.any((g) => relationKey.startsWith('${g}_'));

  final String? relationKey;
  final String? relationLabel;
  final String occasionKey;

  // Step 2 (`257:755`)
  final String title;
  final DateTime? date;
  final TimeOfDayValue? time;
  final String venue;
  final String description;

  /// The card the host designed or the file they picked, waiting for the
  /// event it will be attached to. Null until the invitation step is done.
  final PendingInvitation? invitation;

  /// The server's id for [invitation] once it has gone up — kept so a retry
  /// after a failed create does not upload the same bytes twice.
  final String? inviteMediaId;

  /// The event, once [CreateEventController.publish] has created it. Kept so
  /// a retry after a failed publish does not create a second one.
  final WishtickEventDetail? created;
  final String? error;
  final bool busy;

  ({String key, String label, EventType type}) get occasion =>
      kEventOccasions.firstWhere(
        (o) => o.key == occasionKey,
        orElse: () => kEventOccasions.first,
      );

  /// Step 1's asterisks: a person and a relation.
  bool get step1Complete =>
      forSelf || (personName.trim().isNotEmpty && relationKey != null);

  /// Step 2's: everything on `257:755` carries one.
  bool get step2Complete =>
      title.trim().isNotEmpty &&
      date != null &&
      time != null &&
      venue.trim().isNotEmpty &&
      description.trim().isNotEmpty;

  /// The date and time as one instant, in the device's zone.
  ///
  /// Composed here rather than in the repository so the screen can show what
  /// it will send — and so a date without a time can never quietly become
  /// midnight.
  DateTime? get startsAt {
    final day = date;
    final at = time;
    if (day == null || at == null) return null;
    return DateTime(day.year, day.month, day.day, at.hour, at.minute);
  }

  CreateEventState copyWith({
    String? personName,
    bool? forSelf,
    String? wishmateId,
    String? relationKey,
    String? relationLabel,
    String? occasionKey,
    String? title,
    DateTime? date,
    TimeOfDayValue? time,
    String? venue,
    String? description,
    PendingInvitation? invitation,
    String? inviteMediaId,
    WishtickEventDetail? created,
    String? error,
    bool? busy,
    bool clearError = false,
    bool clearDate = false,
    bool clearWishmate = false,
    bool clearRelation = false,
    bool clearInviteMediaId = false,
  }) => CreateEventState(
    personName: personName ?? this.personName,
    forSelf: forSelf ?? this.forSelf,
    wishmateId: clearWishmate ? null : (wishmateId ?? this.wishmateId),
    relationKey: clearRelation ? null : (relationKey ?? this.relationKey),
    relationLabel: clearRelation ? null : (relationLabel ?? this.relationLabel),
    occasionKey: occasionKey ?? this.occasionKey,
    title: title ?? this.title,
    date: clearDate ? null : (date ?? this.date),
    time: time ?? this.time,
    venue: venue ?? this.venue,
    description: description ?? this.description,
    invitation: invitation ?? this.invitation,
    inviteMediaId: clearInviteMediaId
        ? null
        : (inviteMediaId ?? this.inviteMediaId),
    created: created ?? this.created,
    error: clearError ? null : (error ?? this.error),
    busy: busy ?? this.busy,
  );
}

/// A wall-clock time, kept free of Flutter's `TimeOfDay` so the state stays
/// testable without a widget binding.
@immutable
class TimeOfDayValue {
  const TimeOfDayValue(this.hour, this.minute);

  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is TimeOfDayValue && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// Drives "What are you celebrating?" → "Tell us about your event".
class CreateEventController extends Notifier<CreateEventState> {
  @override
  CreateEventState build() => const CreateEventState();

  /// Typing by hand breaks any WishMate link — the name no longer refers to
  /// the person who was picked — and with it any relation that link allowed.
  /// Leaving, say, "Colleague" selected after the link is gone would submit a
  /// relation the picker would no longer offer.
  void setPersonName(String value) => state = state.copyWith(
    personName: value,
    clearError: true,
    clearWishmate: true,
    clearRelation: !CreateEventState.isRelationOpenToEveryone(
      state.relationKey,
    ),
  );

  /// Whether the event is for the host themself.
  ///
  /// Switching to "me" clears the name, the WishMate link and the relation:
  /// none of them describes the host, and leaving them in the draft would
  /// submit a person and a relation for an event that has neither.
  void setForSelf(bool value) => state = value
      ? state.copyWith(
          forSelf: true,
          personName: '',
          clearWishmate: true,
          clearRelation: true,
          clearError: true,
        )
      : state.copyWith(forSelf: false, clearError: true);

  /// The host picked someone from their WishMates.
  void setWishmate({required String userId, required String name}) => state =
      state.copyWith(personName: name, wishmateId: userId, clearError: true);

  void setRelation(String key, String label) =>
      state = state.copyWith(relationKey: key, relationLabel: label);

  void setOccasion(String key) => state = state.copyWith(occasionKey: key);

  void setTitle(String value) =>
      state = state.copyWith(title: value, clearError: true);

  void setDate(DateTime value) => state = state.copyWith(date: value);

  /// Backs out of a committed date — see
  /// `ProfileFormController.clearDateOfBirth` for why the manual-entry field
  /// needs this.
  void clearDate() => state = state.copyWith(clearDate: true);

  void setTime(TimeOfDayValue value) => state = state.copyWith(time: value);

  void setVenue(String value) => state = state.copyWith(venue: value);

  void setDescription(String value) =>
      state = state.copyWith(description: value);

  /// Suggests an event name from what step 1 collected — "Siya's Birthday".
  ///
  /// Only ever a suggestion: it fills the field once, and an edited title is
  /// never overwritten, because the host's own words beat a generated one.
  String suggestedTitle() {
    if (state.forSelf) {
      // The guests read this, so it is the host's name, not "My": "Siya's
      // Birthday" invites; "My Birthday" on someone else's phone does not.
      // Without a name on the account there is nothing better than "My".
      final me = ref.read(sessionProvider).user?.name?.trim();
      final who = (me == null || me.isEmpty) ? 'My' : "$me's";
      return '$who ${state.occasion.label}';
    }
    final person = state.personName.trim();
    if (person.isEmpty) return '';
    return "$person's ${state.occasion.label}";
  }

  /// The card the designer exported, or the file the host picked.
  ///
  /// Replaces whatever was there, and forgets any upload of it: a host who
  /// goes back and designs again means the new one, and a stale media id
  /// would attach the old card to the event.
  void setInvitation(Uint8List bytes, String fileName) =>
      state = state.copyWith(
        invitation: PendingInvitation(bytes: bytes, fileName: fileName),
        clearInviteMediaId: true,
        clearError: true,
      );

  /// Back to a blank wizard — once the event exists and the host has moved on
  /// to sharing it. The provider is not auto-disposed, so without this the
  /// next "Create Event" would open on the last one's details.
  void reset() => state = const CreateEventState();

  /// Creates the event — the first request that makes it exist — and
  /// publishes it, in one go.
  ///
  /// Called from the preview, on the way to the share screen, and nowhere
  /// earlier: until the host has seen the finished card there is no event on
  /// the server, so there is no half-made draft for the home rail to show or
  /// for them to have to delete after backing out.
  ///
  /// Three requests — upload the card, create with its id, publish — ordered
  /// so a retry after a failure never makes a second event: the media id and
  /// the created event are kept in the state, and the next call resumes from
  /// whichever step failed.
  ///
  /// [wishlistId] is a list the host made on the way, linked to the event as
  /// it is created.
  Future<WishtickEventDetail?> publish({String? wishlistId}) async {
    if (!state.step2Complete || state.busy) return null;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final repo = ref.read(eventsRepositoryProvider);
      var event = state.created;
      if (event == null) {
        final mediaId = await _uploadInvitation();
        event = await repo.create(
          title: state.title.trim(),
          type: state.occasion.type,
          startsAt: state.startsAt!,
          timezone: kDefaultTimezone,
          description: state.description.trim(),
          venue: state.venue.trim(),
          // For the host's own event neither is sent: the server would
          // otherwise store an empty name and a null relation as if they
          // were answers.
          personName: state.forSelf ? null : state.personName.trim(),
          relation: state.forSelf ? null : state.relationKey,
          forSelf: state.forSelf,
          inviteMediaId: mediaId,
          wishlistIds: wishlistId == null ? null : [wishlistId],
          // Invite-only, not the server's default of private: the share
          // screen this leads to hands out the event's link, and the server
          // answers a private event's link with a 404 for everybody. Invite
          // only is "invitees, plus anyone holding the link" — exactly the
          // two ways the host is offered to invite people.
          visibility: EventVisibility.inviteOnly,
        );
        state = state.copyWith(created: event);
      } else if (wishlistId != null &&
          !event.wishlistIds.contains(wishlistId)) {
        // Created on an earlier attempt, before this wishlist existed.
        event = await repo.update(
          event.id,
          wishlistIds: [...event.wishlistIds, wishlistId],
        );
        state = state.copyWith(created: event);
      }
      if (event.status == EventStatus.draft) {
        event = await repo.publish(event.id);
      }
      state = state.copyWith(busy: false, created: event);
      return event;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return null;
    }
  }

  /// The invitation's media id, uploading it if this is the first attempt.
  Future<String?> _uploadInvitation() async {
    final invitation = state.invitation;
    if (invitation == null) return null;
    final already = state.inviteMediaId;
    if (already != null) return already;

    final media = await ref
        .read(mediaRepositoryProvider)
        .uploadFile(
          file: XFile.fromData(invitation.bytes, name: invitation.fileName),
          purpose: MediaPurpose.eventInvite,
          fileName: invitation.fileName,
        );
    state = state.copyWith(inviteMediaId: media.id);
    return media.id;
  }

  String _message(ApiException e) => switch (e.code) {
    'EVENT_LIMIT_REACHED' =>
      'You already have as many events as Wishtick allows. '
          'Finish or cancel one first.',
    'VALIDATION_FAILED' || 'EVENT_DATE_IN_PAST' =>
      'Check the date — an event has to be in the future.',
    'MEDIA_TYPE_NOT_ALLOWED' =>
      'That file cannot be used as an invitation. Pick a different one.',
    _ => e.message,
  };
}

final createEventProvider =
    NotifierProvider<CreateEventController, CreateEventState>(
      CreateEventController.new,
    );
