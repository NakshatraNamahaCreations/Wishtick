import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// For XFile, which MediaRepository takes. cross_file is not a direct
// dependency; image_picker re-exports it and is.
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_repository.dart';
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
  relation('Relation');

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
    this.occasionKey = 'birthday',
    this.occasionDay = 17,
    this.occasionMonth = 7,
    this.occasionYear,
    this.includeYear = false,
    this.wishKind,
    this.wishText = '',
    this.wishFilePath,
    this.wishFileName,
    this.unlockDate,
    this.unlockDateChosen = false,
    this.unlockTime = const MemoryTimeOfDay(0, 0),
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
  final String occasionKey;
  final int occasionDay;
  final int occasionMonth;
  final int? occasionYear;
  final bool includeYear;

  /// How the host wants to record their own first wish, chosen between naming
  /// the memory and sealing it.
  ///
  /// Held on the draft rather than posted straight away because the capsule
  /// does not exist yet — `/memories/:id/wishes` needs an id, and the id only
  /// arrives when [CreateMemoryController.submit] creates it.
  final MemoryWishKind? wishKind;

  /// The host's own first wish, composed while the capsule is still a draft.
  ///
  /// Optional on a media wish and required on a text one, exactly as the
  /// contributor's compose screen has it — the label says "(Optional)", and
  /// the rule has to match the label.
  final String wishText;

  /// The picked file, still on the device.
  ///
  /// Deliberately not uploaded yet. A memory is only real once the host sets
  /// its unlock moment and confirms, and plenty of drafts are abandoned before
  /// that — uploading on pick would leave those files in storage, paid for and
  /// referenced by nothing. The bytes go up in [CreateMemoryController.submit],
  /// which is the first moment they are certainly wanted.
  final String? wishFilePath;

  /// The file's real name, which the picker's own path may not carry — an
  /// upload named wrongly is a `.m4a` stored as a JPEG.
  final String? wishFileName;

  /// Whether the composed wish is complete enough to preview.
  bool get wishReady => switch (wishKind) {
    null => false,
    MemoryWishKind.text => wishText.trim().isNotEmpty,
    _ => wishFilePath != null,
  };

  // Step 3 (`2198:73`)
  final DateTime? unlockDate;

  /// Whether [unlockDate] came from the host rather than from the occasion.
  ///
  /// Kept so returning to step 2 after changing the occasion re-derives the
  /// suggestion, while a date the host typed or picked is never overwritten.
  final bool unlockDateChosen;

  /// When on the unlock day the capsule opens. Defaults to midnight, so the
  /// memory is waiting the moment the day starts.
  ///
  /// A real value rather than a placeholder: the field used to *show* 12:00 AM
  /// while holding null, which left Save & Continue disabled for a form that
  /// looked complete — and the only way out was to tap the picker and choose
  /// the time it was already displaying. Still fully editable; this only
  /// decides where the picker starts.
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

  /// What step 2's Unlock Date starts on, derived from the occasion picked in
  /// step 1.
  ///
  /// A capsule almost always opens on the day it is about, so asking for that
  /// date twice is asking the same question twice. This year, as the occasion
  /// wheel implies — except when that day has already gone, since the field
  /// refuses anything not in the future and prefilling a rejected date would
  /// be worse than leaving it blank. Today counts as gone: the field compares
  /// against `DateTime.now()` and a date is midnight, so today is already past.
  DateTime suggestedUnlockDate({DateTime? now}) {
    final today = now ?? DateTime.now();
    final thisYear = DateTime(today.year, occasionMonth, occasionDay);
    final isAhead = thisYear.isAfter(
      DateTime(today.year, today.month, today.day),
    );
    return isAhead
        ? thisYear
        : DateTime(today.year + 1, occasionMonth, occasionDay);
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
    String? occasionKey,
    int? occasionDay,
    int? occasionMonth,
    int? occasionYear,
    bool? includeYear,
    MemoryWishKind? wishKind,
    String? wishText,
    String? wishFilePath,
    String? wishFileName,
    bool clearWishMedia = false,
    DateTime? unlockDate,
    bool? unlockDateChosen,
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
    occasionKey: occasionKey ?? this.occasionKey,
    occasionDay: occasionDay ?? this.occasionDay,
    occasionMonth: occasionMonth ?? this.occasionMonth,
    occasionYear: occasionYear ?? this.occasionYear,
    includeYear: includeYear ?? this.includeYear,
    wishKind: wishKind ?? this.wishKind,
    wishText: wishText ?? this.wishText,
    wishFilePath: clearWishMedia ? null : (wishFilePath ?? this.wishFilePath),
    wishFileName: clearWishMedia ? null : (wishFileName ?? this.wishFileName),
    unlockDate: clearUnlockDate ? null : (unlockDate ?? this.unlockDate),
    unlockDateChosen: unlockDateChosen ?? this.unlockDateChosen,
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

  void setOccasion(String key) => state = state.copyWith(occasionKey: key);

  void setOccasionDay(int day) => state = state.copyWith(occasionDay: day);

  void setOccasionMonth(int month) =>
      state = state.copyWith(occasionMonth: month);

  void setOccasionYear(int year) => state = state.copyWith(occasionYear: year);

  void setIncludeYear(bool value) => state = state.copyWith(includeYear: value);

  /// Picks how the host will record their wish.
  ///
  /// Changing the kind drops whatever was picked for the previous one — a
  /// video left behind on a wish that is now a voice note would be uploaded,
  /// paid for, and never shown.
  void setWishKind(MemoryWishKind value) {
    if (state.wishKind == value) return;
    state = state.copyWith(wishKind: value, clearWishMedia: true);
  }

  void setWishText(String value) => state = state.copyWith(wishText: value);

  /// Remembers the picked file. Nothing is uploaded until submit.
  void setWishFile({required String path, required String name}) =>
      state = state.copyWith(wishFilePath: path, wishFileName: name);

  void clearWishMedia() => state = state.copyWith(clearWishMedia: true);

  void setUnlockDate(DateTime value) =>
      state = state.copyWith(unlockDate: value, unlockDateChosen: true);

  /// Starts step 2 on the occasion's own date.
  ///
  /// Called on the way out of step 1, not on the way into step 2: the date
  /// field reads its initial value once, when it is built, so a suggestion
  /// that lands afterwards would sit in the state and never reach the box.
  ///
  /// Never overwrites a date the host chose — but a *suggestion* is refreshed,
  /// so going back, changing the occasion and returning follows the change
  /// rather than leaving the first guess behind.
  void suggestUnlockDate() {
    if (state.unlockDateChosen) return;
    state = state.copyWith(unlockDate: state.suggestedUnlockDate());
  }

  /// Backs out of a committed date — see
  /// `ProfileFormController.clearDateOfBirth` for why the manual-entry field
  /// needs this.
  void clearUnlockDate() =>
      state = state.copyWith(clearUnlockDate: true, unlockDateChosen: true);

  void setUnlockTime(MemoryTimeOfDay value) =>
      state = state.copyWith(unlockTime: value);

  /// Creates the capsule, sealed. Nothing inside it is readable — by anyone,
  /// including the host — until it opens.
  Future<MemoryCapsule?> submit() async {
    final unlockAt = state.unlockAt;
    if (!state.step1Complete || unlockAt == null || state.busy) return null;

    state = state.copyWith(busy: true, clearError: true);
    try {
      // The wish's bytes go up first, before anything is created. If the
      // upload fails there is nothing to undo — better than a sealed capsule
      // whose only wish never made it.
      final wishMediaId = await _uploadWishMedia();

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
            occasionDate: state.occasionDateValue,
            includeYear: state.includeYear,
          );
      await _postFirstWish(capsule.id, wishMediaId);
      state = state.copyWith(busy: false, created: capsule);
      return capsule;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return null;
    }
  }

  /// Adds the wish the host composed during creation, now that there is a
  /// capsule to add it to.
  ///
  /// Deliberately does not fail the creation. The memory exists by this point
  /// and is the thing the host asked for; losing the whole capsule because one
  /// wish did not post would be a far worse outcome than a memory the host can
  /// add a wish to from its own screen. The wish is kept on the draft so a
  /// retry has something to send.
  /// Uploads the file the host picked, at the moment it is certainly wanted.
  ///
  /// Nothing was sent while they were composing: a memory only becomes real
  /// when its unlock moment is confirmed, and every abandoned draft before
  /// that would otherwise have left a paid-for file referenced by nothing.
  Future<String?> _uploadWishMedia() async {
    final path = state.wishFilePath;
    final name = state.wishFileName;
    if (path == null || name == null) return null;

    final media = await ref
        .read(mediaRepositoryProvider)
        .uploadFile(
          file: XFile(path),
          purpose: MediaPurpose.memoryWish,
          // XFile's own name can be the picker's temp path, so the real one is
          // handed over separately — otherwise a .m4a uploads as a JPEG.
          fileName: name,
        );
    return media.id;
  }

  Future<void> _postFirstWish(String capsuleId, String? mediaId) async {
    final kind = state.wishKind;
    if (kind == null || !state.wishReady) return;

    try {
      await ref
          .read(memoriesRepositoryProvider)
          .addWish(
            capsuleId,
            kind: kind,
            text: state.wishText.trim().isEmpty ? null : state.wishText.trim(),
            mediaId: mediaId,
          );
    } on ApiException catch (e) {
      debugPrint('First wish failed for $capsuleId: ${e.message}');
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
