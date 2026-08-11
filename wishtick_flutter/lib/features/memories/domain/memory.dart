import 'package:flutter/foundation.dart';

/// Where a capsule is in its life.
///
/// `unlocked` is the only status in which wish content exists at all — the
/// server withholds it otherwise, so an empty `wishes` on a sealed capsule
/// means "sealed", never "nobody wrote anything".
enum MemoryStatus {
  collecting('collecting'),
  locked('locked'),
  unlocked('unlocked');

  const MemoryStatus(this.wireValue);

  final String wireValue;

  static MemoryStatus fromWire(String? value) => MemoryStatus.values.firstWhere(
    (v) => v.wireValue == value,
    orElse: () => collecting,
  );

  bool get isOpen => this == unlocked;
}

/// What a contributed wish is (`2073:55`, `2078:233`, `2074:129`, audio).
enum MemoryWishKind {
  photo('photo'),
  text('text'),
  audio('audio'),
  video('video');

  const MemoryWishKind(this.wireValue);

  final String wireValue;

  static MemoryWishKind fromWire(String? value) => MemoryWishKind.values
      .firstWhere((v) => v.wireValue == value, orElse: () => text);

  /// The words the add-a-wish screens title themselves with.
  String get label => switch (this) {
    MemoryWishKind.photo => 'Photo Message',
    MemoryWishKind.text => 'Write Message',
    MemoryWishKind.audio => 'Voice Note',
    MemoryWishKind.video => 'Video Message',
  };

  /// Text is the only kind that carries no file.
  bool get needsMedia => this != MemoryWishKind.text;
}

/// One wish inside an opened capsule (`2078:357` and its variants).
@immutable
class MemoryWish {
  const MemoryWish({
    required this.id,
    required this.contributorName,
    required this.kind,
    required this.durationMs,
    required this.reactionCount,
    required this.createdAt,
    this.contributorAvatarUrl,
    this.text,
    this.mediaUrl,
    this.contentType,
  });

  final String id;
  final String contributorName;
  final String? contributorAvatarUrl;
  final MemoryWishKind kind;
  final String? text;
  final String? mediaUrl;
  final String? contentType;

  /// Audio and video length, as the transport row shows. 0 otherwise.
  final int durationMs;

  final int reactionCount;
  final DateTime createdAt;

  Duration get duration => Duration(milliseconds: durationMs);

  factory MemoryWish.fromJson(Map<String, dynamic> json) => MemoryWish(
    id: json['id'] as String,
    contributorName: json['contributorName'] as String? ?? 'A friend',
    contributorAvatarUrl: json['contributorAvatarUrl'] as String?,
    kind: MemoryWishKind.fromWire(json['kind'] as String?),
    text: json['text'] as String?,
    mediaUrl: json['mediaUrl'] as String?,
    contentType: json['contentType'] as String?,
    durationMs: json['durationMs'] as int? ?? 0,
    reactionCount: json['reactionCount'] as int? ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  MemoryWish copyWith({int? reactionCount}) => MemoryWish(
    id: id,
    contributorName: contributorName,
    contributorAvatarUrl: contributorAvatarUrl,
    kind: kind,
    text: text,
    mediaUrl: mediaUrl,
    contentType: contentType,
    durationMs: durationMs,
    reactionCount: reactionCount ?? this.reactionCount,
    createdAt: createdAt,
  );
}

/// The contribute link. Host-only — it is how people are invited in.
@immutable
class MemoryShare {
  const MemoryShare({required this.slug, required this.url});

  final String slug;
  final String url;

  factory MemoryShare.fromJson(Map<String, dynamic> json) => MemoryShare(
    slug: json['slug'] as String,
    url: json['url'] as String? ?? '',
  );
}

/// A time-locked capsule (`4104:1539`, `4104:1433`).
@immutable
class MemoryCapsule {
  const MemoryCapsule({
    required this.id,
    required this.title,
    required this.personName,
    required this.occasion,
    required this.status,
    required this.unlockAt,
    required this.timezone,
    required this.wishCount,
    required this.contributors,
    required this.hostId,
    required this.isHost,
    required this.includeYear,
    required this.createdAt,
    required this.wishes,
    this.relation,
    this.description,
    this.occasionDate,
    this.coverUrl,
    this.unlockedAt,
    this.share,
  });

  final String id;
  final String title;
  final String personName;

  /// A `relation` taxonomy key, not a label.
  final String? relation;

  final String? description;

  /// An `occasion` taxonomy key — the eight tiles on `4104:1539`.
  final String occasion;

  /// The occasion's own date, which is not [unlockAt]: a birthday is in July
  /// whether or not the capsule opens the night before.
  final DateTime? occasionDate;

  final bool includeYear;
  final String? coverUrl;
  final MemoryStatus status;
  final DateTime unlockAt;
  final DateTime? unlockedAt;
  final String timezone;
  final int wishCount;

  /// First names only — the metadata the server shows while it is sealed.
  final List<String> contributors;

  final String hostId;
  final bool isHost;
  final DateTime createdAt;

  /// Empty until the capsule opens. That is the time-lock, not a loading state.
  final List<MemoryWish> wishes;

  final MemoryShare? share;

  bool get isOpen => status.isOpen;

  /// How long until it opens. Negative once the instant has passed but the
  /// unlock job has not yet run — the status, not the clock, decides.
  Duration get untilUnlock => unlockAt.difference(DateTime.now());

  /// "Unlocks in 5 days" (`4104:1433`).
  String get countdownLabel {
    if (isOpen) return 'Unlocked';
    final left = untilUnlock;
    if (left.isNegative) return 'Unlocking…';
    if (left.inDays >= 1) {
      return 'Unlocks in ${left.inDays} ${left.inDays == 1 ? 'day' : 'days'}';
    }
    if (left.inHours >= 1) {
      return 'Unlocks in ${left.inHours} ${left.inHours == 1 ? 'hour' : 'hours'}';
    }
    return 'Unlocks in ${left.inMinutes} min';
  }

  factory MemoryCapsule.fromJson(Map<String, dynamic> json) => MemoryCapsule(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    personName: json['personName'] as String? ?? '',
    relation: json['relation'] as String?,
    description: json['description'] as String?,
    occasion: json['occasion'] as String? ?? 'birthday',
    occasionDate: json['occasionDate'] == null
        ? null
        : DateTime.parse(json['occasionDate'] as String),
    includeYear: json['includeYear'] as bool? ?? false,
    coverUrl: json['coverUrl'] as String?,
    status: MemoryStatus.fromWire(json['status'] as String?),
    unlockAt: DateTime.parse(json['unlockAt'] as String),
    unlockedAt: json['unlockedAt'] == null
        ? null
        : DateTime.parse(json['unlockedAt'] as String),
    timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
    wishCount: json['wishCount'] as int? ?? 0,
    contributors:
        (json['contributors'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const [],
    hostId: json['hostId'] as String? ?? '',
    isHost: json['isHost'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    wishes:
        (json['wishes'] as List<dynamic>?)
            ?.map((e) => MemoryWish.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    share: json['share'] == null
        ? null
        : MemoryShare.fromJson(json['share'] as Map<String, dynamic>),
  );
}
