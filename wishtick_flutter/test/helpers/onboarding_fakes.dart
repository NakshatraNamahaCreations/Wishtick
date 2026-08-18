import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/onboarding/domain/onboarding_options.dart';
import 'package:wishtick_flutter/features/onboarding/domain/profile_draft.dart';

/// A compact but structurally-faithful option catalogue for tests: two
/// categories with two sub-interests each plus "other" suggestions, one colour
/// group, sizes in two systems, fits, and occasions.
OnboardingOptions buildOptions() {
  TaxonomyOption option(
    String key,
    String label, [
    Map<String, String>? meta,
  ]) => TaxonomyOption(key: key, label: label, meta: meta);

  return OnboardingOptions(
    interestCategories: [
      option('fashion', 'Fashion & Personal Style'),
      option('technology', 'Technology & Gadgets'),
      option('other', 'Other'),
    ],
    interests: [
      option('fashion_shoes', 'Shoes', {'category': 'fashion'}),
      option('fashion_watches', 'Watches', {'category': 'fashion'}),
      option('tech_gaming', 'Gaming', {'category': 'technology'}),
      option('tech_smartphones', 'Smartphones', {'category': 'technology'}),
      option('other_anime', 'Anime', {'category': 'other'}),
    ],
    colors: [
      option('purple_plum', 'Plum', {
        'hex': '#5B1A6E',
        'group': 'purple',
        'groupLabel': 'Purple & Violet',
      }),
      option('green_sage', 'Sage', {
        'hex': '#A7C3AA',
        'group': 'green',
        'groupLabel': 'Greens',
      }),
    ],
    clothingSizes: [option('xs', 'XS'), option('m', 'M')],
    shoeSizes: [
      option('uk_9', 'UK 9', {'system': 'uk'}),
      option('us_9', 'US 9', {'system': 'us'}),
    ],
    fitPreferences: [option('regular', 'Regular'), option('slim', 'Slim')],
    occasions: [
      option('birthday', 'Birthday'),
      option('special_moments', 'Special Moments'),
    ],
  );
}

OnboardingStatus buildStatus({
  bool completed = false,
  List<String> completedSteps = const [],
}) {
  return OnboardingStatus(
    completed: completed,
    completedSteps: completedSteps,
    remainingRequiredSteps: completed ? const [] : const ['profile'],
  );
}

/// Scriptable stand-in for the onboarding API.
class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({this.completed = false, OnboardingOptions? options})
    // ignore: prefer_initializing_formals
    : _options = options;

  /// Overrides [buildOptions] when a test needs a specific catalogue shape
  /// (e.g. real colour-group keys) rather than the compact default.
  final OnboardingOptions? _options;

  /// What `status()` reports, and what a save flips once the profile is stored.
  bool completed;

  int statusCalls = 0;
  final savedProfiles = <ProfileDraft>[];

  /// When set, the next `saveProfile` throws this.
  ApiException? saveFailure;

  /// When set, `status()` throws this.
  ApiException? statusFailure;

  @override
  Future<OnboardingStatus> status() async {
    statusCalls++;
    final failure = statusFailure;
    if (failure != null) throw failure;
    return buildStatus(
      completed: completed,
      completedSteps: completed ? const ['profile'] : const [],
    );
  }

  @override
  Future<OnboardingStatus> saveProfile(ProfileDraft draft) async {
    final failure = saveFailure;
    if (failure != null) throw failure;
    savedProfiles.add(draft);
    return buildStatus(completedSteps: const ['profile']);
  }

  @override
  Future<OnboardingStatus> complete() async {
    final failure = completeFailure;
    if (failure != null) throw failure;
    completed = true;
    return buildStatus(completed: true, completedSteps: const ['profile']);
  }

  /// When set, `complete()` throws this.
  ApiException? completeFailure;

  /// When set, `options()` throws this.
  ApiException? optionsFailure;

  /// When set, the step saves throw this.
  ApiException? stepFailure;

  int optionsCalls = 0;

  /// What each save received, for assertions.
  ({List<String> categories, List<String> interests, List<String> customs})?
  savedInterests;
  List<String>? savedColors;
  ({String? clothing, String? shoe, String? fit})? savedSizes;
  final dates = <ImportantDate>[];
  int _dateSeq = 0;

  @override
  Future<OnboardingOptions> options() async {
    optionsCalls++;
    final failure = optionsFailure;
    if (failure != null) throw failure;
    return _options ?? buildOptions();
  }

  @override
  Future<OnboardingStatus> saveInterests({
    required List<String> interestCategories,
    required List<String> interests,
    required List<String> customInterests,
  }) async {
    final failure = stepFailure;
    if (failure != null) throw failure;
    savedInterests = (
      categories: interestCategories,
      interests: interests,
      customs: customInterests,
    );
    return buildStatus(completedSteps: const ['profile', 'interests']);
  }

  @override
  Future<OnboardingStatus> saveColors(List<String> favouriteColors) async {
    final failure = stepFailure;
    if (failure != null) throw failure;
    savedColors = favouriteColors;
    return buildStatus(completedSteps: const ['profile', 'sizes']);
  }

  @override
  Future<OnboardingStatus> saveSizes({
    String? clothingSize,
    String? shoeSize,
    String? fitPreference,
  }) async {
    final failure = stepFailure;
    if (failure != null) throw failure;
    savedSizes = (clothing: clothingSize, shoe: shoeSize, fit: fitPreference);
    return buildStatus(completedSteps: const ['profile', 'sizes']);
  }

  @override
  Future<List<ImportantDate>> listImportantDates() async => List.of(dates);

  @override
  Future<ImportantDate> addImportantDate({
    required String personName,
    required String relation,
    required String occasionKey,
    required String dateIso,
  }) async {
    final failure = stepFailure;
    if (failure != null) throw failure;
    final saved = ImportantDate(
      id: 'date_${++_dateSeq}',
      personName: personName,
      relation: relation,
      occasionKey: occasionKey,
      date: dateIso,
    );
    dates.add(saved);
    return saved;
  }

  @override
  Future<void> removeImportantDate(String id) async {
    dates.removeWhere((d) => d.id == id);
  }
}
