import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/presentation/onboarding_options_provider.dart';

/// `occasionKey` → display label, from the same taxonomy important-dates uses.
///
/// Derived from [onboardingOptionsProvider] rather than fetching again, so a
/// screen showing occasions and one showing relations share a single request.
final occasionLabelsProvider = FutureProvider<Map<String, String>>((ref) async {
  final options = await ref.watch(onboardingOptionsProvider.future);
  return {for (final o in options.occasions) o.key: o.label};
});
