import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/memories_repository.dart';
import '../domain/memory.dart';

/// The occasion tiles on `4104:1539`, mapped to `occasion` taxonomy keys.
///
/// The same eight the event-creation grid shows, because they are the same
/// eight illustrations — but these carry taxonomy keys rather than `EventType`,
/// since a capsule stores the occasion the host actually picked.
const kMemoryOccasions = <({String key, String label})>[
  (key: 'birthday', label: 'Birthday'),
  (key: 'anniversary', label: 'Anniversary'),
  (key: 'wedding', label: 'Wedding'),
  (key: 'housewarming', label: 'House Warming'),
  (key: 'baby_shower', label: 'Mom to Be'),
  (key: 'just_because', label: 'Custom Events'),
  (key: 'rakhi', label: 'Rakhi'),
  (key: 'best_wishes', label: 'Best Wishes'),
];

/// The description counter on `4104:1539` reads "12/40".
const kMemoryDescriptionMax = 400;

/// A wall-clock time, kept free of Flutter's `TimeOfDay` so the state stays
/// testable without a widget binding.
@immutable
class MemoryTimeOfDay {
  const MemoryTimeOfDay(this.hour, this.minute);

  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is MemoryTimeOfDay && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// The draft a capsule is composed from, across both create steps.
@immutable
class CreateMemoryState {
  const CreateMemoryState({
    this.title = '',
    this.personName = '',
    this.relationKey,
    this.relationLabel,
    this.description = '',
    this.occasionKey = 'birthday',
    this.occasionDay = 17,
    this.occasionMonth = 7,
    this.occasionYear,
    this.includeYear = false,
    this.coverMediaId,
    this.coverLocalPath,
    this.unlockDate,
    this.unlockTime,
    this.created,
    this.error,
    this.busy = false,
  });

  // Step 1 (`4104:1539`)
  final String title;
  final String personName;
  final String? relationKey;
  final String? relationLabel;
  final String description;
  final String occasionKey;
  final int occasionDay;
  final int occasionMonth;
  final int? occasionYear;
  final bool includeYear;
  final String? coverMediaId;

  /// The picked file's path, so the tile shows the photo before it uploads.
  final String? coverLocalPath;

  // Step 2 (`2198:73`)
  final DateTime? unlockDate;
  final MemoryTimeOfDay? unlockTime;

  final MemoryCapsule? created;
  final String? error;
  final bool busy;

  ({String key, String label}) get occasion => kMemoryOccasions.firstWhere(
    (o) => o.key == occasionKey,
    orElse: () => kMemoryOccasions.first,
  );

  /// Everything `4104:1539` marks with an asterisk.
  bool get step1Complete =>
      title.trim().isNotEmpty &&
      personName.trim().isNotEmpty &&
      relationKey != null &&
      description.trim().isNotEmpty;

  bool get step2Complete => unlockDate != null && unlockTime != null;

  /// The occasion's own date. Without a year it is stored against the coming
  /// occurrence, so "17 July" means the next 17 July rather than the year 0.
  DateTime get occasionDateValue {
    final year = includeYear
        ? (occasionYear ?? DateTime.now().year)
        : DateTime.now().year;
    return DateTime(year, occasionMonth, occasionDay);
  }

  /// The unlock instant, in the device's zone.
  ///
  /// Composed here rather than in the repository so the screen can show what it
  /// will send — and so a date without a time can never quietly become midnight.
  DateTime? get unlockAt {
    final day = unlockDate;
    final at = unlockTime;
    if (day == null || at == null) return null;
    return DateTime(day.year, day.month, day.day, at.hour, at.minute);
  }

  CreateMemoryState copyWith({
    String? title,
    String? personName,
    String? relationKey,
    String? relationLabel,
    String? description,
    String? occasionKey,
    int? occasionDay,
    int? occasionMonth,
    int? occasionYear,
    bool? includeYear,
    String? coverMediaId,
    String? coverLocalPath,
    DateTime? unlockDate,
    MemoryTimeOfDay? unlockTime,
    MemoryCapsule? created,
    String? error,
    bool? busy,
    bool clearError = false,
  }) => CreateMemoryState(
    title: title ?? this.title,
    personName: personName ?? this.personName,
    relationKey: relationKey ?? this.relationKey,
    relationLabel: relationLabel ?? this.relationLabel,
    description: description ?? this.description,
    occasionKey: occasionKey ?? this.occasionKey,
    occasionDay: occasionDay ?? this.occasionDay,
    occasionMonth: occasionMonth ?? this.occasionMonth,
    occasionYear: occasionYear ?? this.occasionYear,
    includeYear: includeYear ?? this.includeYear,
    coverMediaId: coverMediaId ?? this.coverMediaId,
    coverLocalPath: coverLocalPath ?? this.coverLocalPath,
    unlockDate: unlockDate ?? this.unlockDate,
    unlockTime: unlockTime ?? this.unlockTime,
    created: created ?? this.created,
    error: clearError ? null : (error ?? this.error),
    busy: busy ?? this.busy,
  );
}

/// Drives "Create Memory" → "When should this Memory Unlock?".
class CreateMemoryController extends Notifier<CreateMemoryState> {
  @override
  CreateMemoryState build() => const CreateMemoryState();

  void setTitle(String value) =>
      state = state.copyWith(title: value, clearError: true);

  void setPersonName(String value) =>
      state = state.copyWith(personName: value, clearError: true);

  void setRelation(String key, String label) =>
      state = state.copyWith(relationKey: key, relationLabel: label);

  void setDescription(String value) =>
      state = state.copyWith(description: value);

  void setOccasion(String key) => state = state.copyWith(occasionKey: key);

  void setOccasionDay(int day) => state = state.copyWith(occasionDay: day);

  void setOccasionMonth(int month) =>
      state = state.copyWith(occasionMonth: month);

  void setOccasionYear(int year) => state = state.copyWith(occasionYear: year);

  void setIncludeYear(bool value) => state = state.copyWith(includeYear: value);

  void setCover({required String mediaId, required String localPath}) =>
      state = state.copyWith(coverMediaId: mediaId, coverLocalPath: localPath);

  void setUnlockDate(DateTime value) =>
      state = state.copyWith(unlockDate: value);

  void setUnlockTime(MemoryTimeOfDay value) =>
      state = state.copyWith(unlockTime: value);

  /// Creates the capsule, sealed. Nothing inside it is readable — by anyone,
  /// including the host — until it opens.
  Future<MemoryCapsule?> submit() async {
    final unlockAt = state.unlockAt;
    if (!state.step1Complete || unlockAt == null || state.busy) return null;

    state = state.copyWith(busy: true, clearError: true);
    try {
      final capsule = await ref
          .read(memoriesRepositoryProvider)
          .create(
            title: state.title.trim(),
            personName: state.personName.trim(),
            occasion: state.occasionKey,
            unlockAt: unlockAt,
            // The server requires an IANA zone and Dart cannot report one —
            // see kDefaultTimezone in the events create controller.
            timezone: kMemoryTimezone,
            relation: state.relationKey,
            description: state.description.trim(),
            occasionDate: state.occasionDateValue,
            includeYear: state.includeYear,
            coverMediaId: state.coverMediaId,
          );
      state = state.copyWith(busy: false, created: capsule);
      return capsule;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return null;
    }
  }

  String _message(ApiException e) => switch (e.code) {
    'VALIDATION_FAILED' =>
      'Pick an unlock moment in the future — a memory that is already '
          'open is not a surprise.',
    'RATE_LIMITED' =>
      'You already have as many sealed memories as Wishtick allows.',
    _ => e.message,
  };
}

/// The zone a capsule is created in.
///
/// The server requires an **IANA** zone and rejects anything it cannot resolve;
/// `DateTime.now().timeZoneName` gives `IST`/`GMT+05:30`, which fails that
/// check. Same constant and the same reason as the events create flow.
const kMemoryTimezone = 'Asia/Kolkata';

final createMemoryProvider =
    NotifierProvider<CreateMemoryController, CreateMemoryState>(
      CreateMemoryController.new,
    );
