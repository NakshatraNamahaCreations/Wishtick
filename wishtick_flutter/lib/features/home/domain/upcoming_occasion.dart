import 'package:flutter/foundation.dart';

/// A saved important date resolved against today
/// (`GET /me/important-dates/upcoming`).
///
/// Recurrence is by month/day server-side, so a birthday saved with a 1999
/// date surfaces every year.
@immutable
class UpcomingOccasion {
  const UpcomingOccasion({
    required this.id,
    required this.personName,
    required this.relation,
    required this.occasionKey,
    required this.date,
    required this.nextOccurrence,
    required this.daysAway,
    required this.turningAge,
  });

  final String id;
  final String personName;

  /// Free text, as the user typed it — "Best Friend", "Mom".
  final String relation;
  final String occasionKey;

  /// The date as saved, date-only ISO.
  final String date;

  /// The next occurrence, date-only ISO. Always today or later.
  final DateTime nextOccurrence;

  /// Whole days until [nextOccurrence]; 0 means today.
  final int daysAway;

  /// Which anniversary this is — 24 for someone born 24 years ago. Null when
  /// the stored year carries no age.
  final int? turningAge;

  bool get isToday => daysAway == 0;

  factory UpcomingOccasion.fromJson(Map<String, dynamic> json) =>
      UpcomingOccasion(
        id: json['id'] as String,
        personName: json['personName'] as String,
        relation: json['relation'] as String,
        occasionKey: json['occasionKey'] as String,
        date: json['date'] as String,
        nextOccurrence: DateTime.parse(json['nextOccurrence'] as String),
        daysAway: json['daysAway'] as int? ?? 0,
        turningAge: json['turningAge'] as int?,
      );
}
