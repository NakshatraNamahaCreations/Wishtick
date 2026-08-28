import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../wishmates/domain/wishmate.dart';
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

/// A required field on step 1, in the order it appears on screen.
///
/// One list rather than a set of booleans: the same order drives the sentence
/// the toast reads out, which field gets outlined, and which one the screen
/// scrolls to — three things that have to agree, and would not for long if
/// each were written separately.
enum MemoryField {
  title('Memory name'),
  recipient('WishMate'),
  relation('Relation'),
  description('Description');

  const MemoryField(this.label);

  /// How the field is named to the user, matching its label on the form.
  final String label;
}

/// The draft a capsule is composed from, across both create steps.
@immutable
class CreateMemoryState {
  const CreateMemoryState({
    this.title = '',
    this.recipient,
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
    this.showValidation = false,
  });

  // Step 1 (`4104:1539`)
  final String title;

  /// Who the memory is for — picked from the host's WishMates rather than
  /// typed. The server refuses a recipient the host is not linked to, so a
  /// name would have nothing to check against.
  final PersonIdentity? recipient;
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

  /// Whether the form has been submitted once with something missing.
  ///
  /// Errors stay hidden until then: marking a field red before anyone has
  /// touched it tells a user they have done something wrong on arrival.
  final bool showValidation;

  /// Everything `4104:1539` marks with an asterisk, in screen order.
  List<MemoryField> get missingStep1 => [
    if (title.trim().isEmpty) MemoryField.title,
    if (recipient == null) MemoryField.recipient,
    if (relationKey == null) MemoryField.relation,
    if (description.trim().isEmpty) MemoryField.description,
  ];

  bool get step1Complete => missingStep1.isEmpty;

  /// What the toast says when Save & Continue is pressed too early.
  ///
  /// Names the fields rather than saying "some fields are required": the whole
  /// problem is that a greyed-out button tells you nothing, and a message that
  /// also tells you nothing is no better.
  String get missingMessage {
    final labels = missingStep1.map((f) => f.label).toList();
    if (labels.isEmpty) return '';
    final list = labels.length == 1
        ? labels.single
        : '${labels.take(labels.length - 1).join(', ')} and ${labels.last}';
    return 'Add the $list to continue.';
  }

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
    PersonIdentity? recipient,
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
    bool? showValidation,
    bool clearError = false,
    bool clearUnlockDate = false,
  }) => CreateMemoryState(
    title: title ?? this.title,
    recipient: recipient ?? this.recipient,
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
    unlockDate: clearUnlockDate ? null : (unlockDate ?? this.unlockDate),
    unlockTime: unlockTime ?? this.unlockTime,
    created: created ?? this.created,
    error: clearError ? null : (error ?? this.error),
    busy: busy ?? this.busy,
    showValidation: showValidation ?? this.showValidation,
  );
}

/// Drives "Create Memory" → "When should this Memory Unlock?".
class CreateMemoryController extends Notifier<CreateMemoryState> {
  @override
  CreateMemoryState build() => const CreateMemoryState();

  void setTitle(String value) =>
      state = state.copyWith(title: value, clearError: true);

  /// Turns on the red outlines, after a too-early submit.
  ///
  /// One-way: once a user has been shown what is missing, hiding it again as
  /// they fix one field would take the list away mid-repair.
  void revealValidation() => state = state.copyWith(showValidation: true);

  void setRecipient(PersonIdentity value) =>
      state = state.copyWith(recipient: value, clearError: true);

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

  /// Backs out of a committed date — see
  /// `ProfileFormController.clearDateOfBirth` for why the manual-entry field
  /// needs this.
  void clearUnlockDate() => state = state.copyWith(clearUnlockDate: true);

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
            recipientUserId: state.recipient!.userId,
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
