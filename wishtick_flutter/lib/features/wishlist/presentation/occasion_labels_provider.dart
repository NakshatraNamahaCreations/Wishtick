import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/data/onboarding_repository.dart';

/// `occasionKey` → display label, from the same taxonomy important-dates
/// uses (`GET /onboarding/options`). One shared fetch rather than every
/// screen that shows an occasion re-requesting the whole catalogue.
final occasionLabelsProvider = FutureProvider<Map<String, String>>((ref) async {
  final options = await ref.read(onboardingRepositoryProvider).options();
  return {for (final o in options.occasions) o.key: o.label};
});
