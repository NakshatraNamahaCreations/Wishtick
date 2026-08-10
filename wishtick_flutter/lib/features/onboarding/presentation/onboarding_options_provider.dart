import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/onboarding_repository.dart';
import '../domain/onboarding_options.dart';

/// The whole taxonomy — interests, colours, sizes, occasions, relations.
///
/// One shared fetch rather than every screen that needs a corner of it
/// requesting the entire catalogue again. `GET /onboarding/options` is cached
/// server-side for an hour, so a second caller is cheap but not free, and the
/// screens that need it (onboarding, important dates, event creation) can all
/// be on screen in one session.
final onboardingOptionsProvider = FutureProvider<OnboardingOptions>((ref) {
  return ref.watch(onboardingRepositoryProvider).options();
});
