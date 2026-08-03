import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/onboarding_options.dart';
import '../domain/profile_draft.dart';

/// Where the user is in the server-defined onboarding sequence.
class OnboardingStatus {
  const OnboardingStatus({
    required this.completed,
    required this.completedSteps,
    required this.remainingRequiredSteps,
  });

  final bool completed;
  final List<String> completedSteps;
  final List<String> remainingRequiredSteps;

  bool hasCompleted(String step) => completedSteps.contains(step);

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();

    return OnboardingStatus(
      completed: json['completed'] as bool? ?? false,
      completedSteps: strings('completedSteps'),
      remainingRequiredSteps: strings('remainingRequiredSteps'),
    );
  }
}

/// Talks to the backend's `onboarding` module.
///
/// The step list is server-defined (`ONBOARDING_STEPS`), and each step may only
/// write its own fields — posting a field from another step is rejected — so the
/// method per step mirrors that contract rather than exposing a free-form map.
class OnboardingRepository {
  OnboardingRepository(this._api);

  final ApiClient _api;

  /// The five steps, in the order the backend declares them.
  static const stepProfile = 'profile';
  static const stepInterests = 'interests';
  static const stepSizes = 'sizes';
  static const stepGifting = 'gifting';
  static const stepOccasions = 'occasions';

  static const stepCount = 5;

  /// 1-based position of a step, for the "Step N of 5" indicator.
  static int positionOf(String step) => switch (step) {
    stepProfile => 1,
    stepInterests => 2,
    stepSizes => 3,
    stepGifting => 4,
    stepOccasions => 5,
    _ => 1,
  };

  Future<OnboardingStatus> status() async {
    final json = await _api.get<Map<String, dynamic>>('/onboarding/status');
    return OnboardingStatus.fromJson(json);
  }

  /// The server-defined option catalogue every step selects from.
  Future<OnboardingOptions> options() async {
    final json = await _api.get<Map<String, dynamic>>('/onboarding/options');
    return OnboardingOptions.fromJson(json);
  }

  /// Saves step 2 — categories, granular interests, and free-text customs.
  Future<OnboardingStatus> saveInterests({
    required List<String> interestCategories,
    required List<String> interests,
    required List<String> customInterests,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/onboarding/steps/$stepInterests',
      body: {
        'interestCategories': interestCategories,
        'interests': interests,
        'customInterests': customInterests,
      },
    );
    return OnboardingStatus.fromJson(json['status'] as Map<String, dynamic>);
  }

  /// Saves step 3. Colours live on the backend's `sizes` step; sending only
  /// this field leaves the size fields untouched.
  Future<OnboardingStatus> saveColors(List<String> favouriteColors) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/onboarding/steps/$stepSizes',
      body: {'favouriteColors': favouriteColors},
    );
    return OnboardingStatus.fromJson(json['status'] as Map<String, dynamic>);
  }

  /// Saves step 4 — sends only what was chosen so earlier saves survive.
  Future<OnboardingStatus> saveSizes({
    String? clothingSize,
    String? shoeSize,
    String? fitPreference,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/onboarding/steps/$stepSizes',
      body: {
        'clothingSize': ?clothingSize,
        'shoeSize': ?shoeSize,
        'fitPreference': ?fitPreference,
      },
    );
    return OnboardingStatus.fromJson(json['status'] as Map<String, dynamic>);
  }

  // ── Important dates (step 5's data — a profile sub-resource) ──────────────

  Future<List<ImportantDate>> listImportantDates() async {
    final json = await _api.get<List<dynamic>>('/me/important-dates');
    return json
        .map((e) => ImportantDate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ImportantDate> addImportantDate({
    required String personName,
    required String relation,
    required String occasionKey,
    required String dateIso,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/me/important-dates',
      body: {
        'personName': personName,
        'relation': relation,
        'occasionKey': occasionKey,
        'date': dateIso,
      },
    );
    return ImportantDate.fromJson(json);
  }

  Future<void> removeImportantDate(String id) =>
      _api.delete<void>('/me/important-dates/$id');

  /// Saves step 1. Idempotent — re-sending overwrites the same fields.
  Future<OnboardingStatus> saveProfile(ProfileDraft draft) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/onboarding/steps/$stepProfile',
      body: {
        if (draft.hasName) 'displayName': draft.name.trim(),
        if (draft.hasValidEmail) 'email': draft.email.trim(),
        'dateOfBirth': ?draft.dateOfBirthIso,
        'gender': ?draft.gender?.wireValue,
        'avatarKey': ?draft.avatar?.key,
        'photoMediaId': ?draft.photoMediaId,
      },
    );
    return OnboardingStatus.fromJson(json['status'] as Map<String, dynamic>);
  }

  Future<OnboardingStatus> complete() async {
    final json = await _api.post<Map<String, dynamic>>('/onboarding/complete');
    return OnboardingStatus.fromJson(json);
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(apiClientProvider));
});
