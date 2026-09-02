import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/onboarding_options.dart';
import '../../wishmates/domain/wishmate.dart';

/// The user's own important dates, for occasion suggestions.
///
/// A birthday they recorded for a friend is a far better guess at what this
/// list is for than a taxonomy word, so these are offered first.
final importantDatesProvider = FutureProvider<List<ImportantDate>>((ref) {
  return ref.watch(onboardingRepositoryProvider).listImportantDates();
});

/// WishMates whose name matches what has been typed so far.
///
/// Prefix on any word of the name, case-folded, so "si" finds Siya and "sh"
/// finds Priyal Sharma. Empty input offers nobody: a wall of every friend
/// under an empty field is not a suggestion, it is a directory.
List<Wishmate> matchingWishmates(List<Wishmate> mates, String typed) {
  final q = typed.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return mates
      .where((m) => m.name.toLowerCase().split(' ').any((w) => w.startsWith(q)))
      .take(6)
      .toList();
}

/// Occasion suggestions: the user's own dates first, then the taxonomy.
///
/// Dates are worded as the list would be named — "Siya's Birthday" — and
/// de-duplicated against the taxonomy so "Birthday" does not appear twice.
List<String> occasionSuggestions({
  required List<ImportantDate> dates,
  required Map<String, String> taxonomy,
  required String typed,
}) {
  final q = typed.trim().toLowerCase();
  final seen = <String>{};
  final out = <String>[];

  void add(String label) {
    final key = label.toLowerCase();
    if (seen.add(key) && (q.isEmpty || key.contains(q))) out.add(label);
  }

  for (final d in dates) {
    final occasion = taxonomy[d.occasionKey] ?? d.occasionKey;
    add("${d.personName}'s $occasion");
  }
  for (final label in taxonomy.values) {
    add(label);
  }
  return out.take(8).toList();
}
