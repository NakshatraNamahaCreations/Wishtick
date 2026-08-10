import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
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

/// The draft an event is composed from, across both create steps.
@immutable
class CreateEventState {
  const CreateEventState({
    this.personName = '',
    this.relationKey,
    this.relationLabel,
    this.occasionKey = 'birthday',
    this.title = '',
    this.date,
    this.time,
    this.venue = '',
    this.description = '',
    this.created,
    this.error,
    this.busy = false,
  });

  // Step 1 (`257:733`)
  final String personName;
  final String? relationKey;
  final String? relationLabel;
  final String occasionKey;

  // Step 2 (`257:755`)
  final String title;
  final DateTime? date;
  final TimeOfDayValue? time;
  final String venue;
  final String description;

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
      personName.trim().isNotEmpty && relationKey != null;

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
    String? relationKey,
    String? relationLabel,
    String? occasionKey,
    String? title,
    DateTime? date,
    TimeOfDayValue? time,
    String? venue,
    String? description,
    WishtickEventDetail? created,
    String? error,
    bool? busy,
    bool clearError = false,
  }) => CreateEventState(
    personName: personName ?? this.personName,
    relationKey: relationKey ?? this.relationKey,
    relationLabel: relationLabel ?? this.relationLabel,
    occasionKey: occasionKey ?? this.occasionKey,
    title: title ?? this.title,
    date: date ?? this.date,
    time: time ?? this.time,
    venue: venue ?? this.venue,
    description: description ?? this.description,
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

  void setPersonName(String value) =>
      state = state.copyWith(personName: value, clearError: true);

  void setRelation(String key, String label) =>
      state = state.copyWith(relationKey: key, relationLabel: label);

  void setOccasion(String key) => state = state.copyWith(occasionKey: key);

  void setTitle(String value) =>
      state = state.copyWith(title: value, clearError: true);

  void setDate(DateTime value) => state = state.copyWith(date: value);

  void setTime(TimeOfDayValue value) => state = state.copyWith(time: value);

  void setVenue(String value) => state = state.copyWith(venue: value);

  void setDescription(String value) =>
      state = state.copyWith(description: value);

  /// Suggests an event name from what step 1 collected — "Siya's Birthday".
  ///
  /// Only ever a suggestion: it fills the field once, and an edited title is
  /// never overwritten, because the host's own words beat a generated one.
  String suggestedTitle() {
    final person = state.personName.trim();
    if (person.isEmpty) return '';
    return "$person's ${state.occasion.label}";
  }

  /// Creates the event as a **draft** — nothing is sent and no reminders are
  /// scheduled until it is published, which happens after the invitation is
  /// designed.
  Future<WishtickEventDetail?> submit() async {
    if (!state.step2Complete || state.busy) return null;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final event = await ref
          .read(eventsRepositoryProvider)
          .create(
            title: state.title.trim(),
            type: state.occasion.type,
            startsAt: state.startsAt!,
            timezone: kDefaultTimezone,
            description: state.description.trim(),
            venue: state.venue.trim(),
            personName: state.personName.trim(),
            relation: state.relationKey,
          );
      state = state.copyWith(busy: false, created: event);
      return event;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return null;
    }
  }

  String _message(ApiException e) => switch (e.code) {
    'EVENT_LIMIT_REACHED' =>
      'You already have as many events as Wishtick allows. '
          'Finish or cancel one first.',
    'VALIDATION_FAILED' => 'Check the date — an event has to be in the future.',
    _ => e.message,
  };
}

final createEventProvider =
    NotifierProvider<CreateEventController, CreateEventState>(
      CreateEventController.new,
    );
