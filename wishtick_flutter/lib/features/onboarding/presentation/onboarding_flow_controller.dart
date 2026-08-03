import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/onboarding_repository.dart';
import '../domain/onboarding_options.dart';

/// Selection caps shown as "You Selected (n/max)".
///
/// ⚠️ Inferred from the v2 mocks, which all show the counter at capacity
/// ("2/2", "4/4") — confirm the intended maxima with the design team. One
/// place to change if they differ.
abstract final class OnboardingCaps {
  static const interestCategories = 2;
  static const interestsPerCategory = 2;
  static const colors = 4;
  static const customInterests = 10;
}

@immutable
class OnboardingFlowState {
  const OnboardingFlowState({
    this.options,
    this.optionsError,
    this.selectedCategories = const [],
    this.selectedInterests = const {},
    this.customInterests = const [],
    this.selectedColors = const [],
    this.clothingSize,
    this.shoeSize,
    this.shoeSystem = 'uk',
    this.fitPreference,
    this.savedDates = const [],
    this.busy = false,
    this.error,
    this.finished = false,
  });

  /// Loaded once when the flow starts; null while loading.
  final OnboardingOptions? options;
  final String? optionsError;

  /// Step 2 — kept in selection order (the design shows order mattering).
  final List<String> selectedCategories;

  /// Step 2 details — granular picks per category key.
  final Map<String, List<String>> selectedInterests;
  final List<String> customInterests;

  /// Step 3.
  final List<String> selectedColors;

  /// Step 4.
  final String? clothingSize;
  final String? shoeSize;
  final String shoeSystem;
  final String? fitPreference;

  /// Step 5, saved server-side as they are added.
  final List<ImportantDate> savedDates;

  final bool busy;
  final String? error;

  /// Set when `/onboarding/complete` succeeded — the All Set screen shows.
  final bool finished;

  List<String> get allInterests =>
      selectedInterests.values.expand((v) => v).toList();

  /// The category detail screens to walk after the grid, in selection order.
  /// "other" opens the custom-interest screen instead of a photo grid.
  List<String> get detailQueue => selectedCategories;

  bool get hasSizeSelection =>
      clothingSize != null || shoeSize != null || fitPreference != null;

  OnboardingFlowState copyWith({
    OnboardingOptions? options,
    String? optionsError,
    List<String>? selectedCategories,
    Map<String, List<String>>? selectedInterests,
    List<String>? customInterests,
    List<String>? selectedColors,
    String? clothingSize,
    String? shoeSize,
    String? shoeSystem,
    String? fitPreference,
    List<ImportantDate>? savedDates,
    bool? busy,
    String? error,
    bool? finished,
    bool clearError = false,
    bool clearClothing = false,
    bool clearShoe = false,
    bool clearFit = false,
  }) {
    return OnboardingFlowState(
      options: options ?? this.options,
      optionsError: optionsError,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedInterests: selectedInterests ?? this.selectedInterests,
      customInterests: customInterests ?? this.customInterests,
      selectedColors: selectedColors ?? this.selectedColors,
      clothingSize: clearClothing ? null : (clothingSize ?? this.clothingSize),
      shoeSize: clearShoe ? null : (shoeSize ?? this.shoeSize),
      shoeSystem: shoeSystem ?? this.shoeSystem,
      fitPreference: clearFit ? null : (fitPreference ?? this.fitPreference),
      savedDates: savedDates ?? this.savedDates,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      finished: finished ?? this.finished,
    );
  }
}

/// Owns steps 2–5 of onboarding: the option catalogue, every selection, and
/// the step saves. Screens are thin views over this.
class OnboardingFlowController extends Notifier<OnboardingFlowState> {
  @override
  OnboardingFlowState build() => const OnboardingFlowState();

  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  /// Loads the option catalogue once; safe to call from every screen's init.
  Future<void> ensureOptions() async {
    if (state.options != null) return;
    try {
      final options = await _repo.options();
      state = state.copyWith(options: options);
    } on ApiException catch (e) {
      state = state.copyWith(optionsError: _message(e));
    }
  }

  Future<void> retryOptions() async {
    state = state.copyWith(optionsError: null);
    await ensureOptions();
  }

  // ── Step 2: interests ─────────────────────────────────────────────────────

  void toggleCategory(String key) {
    final selected = [...state.selectedCategories];
    if (selected.contains(key)) {
      selected.remove(key);
      // Dropping a category drops its granular picks too.
      final interests = {...state.selectedInterests}..remove(key);
      state = state.copyWith(
        selectedCategories: selected,
        selectedInterests: interests,
        clearError: true,
      );
      return;
    }
    if (selected.length >= OnboardingCaps.interestCategories) return;
    state = state.copyWith(
      selectedCategories: [...selected, key],
      clearError: true,
    );
  }

  void clearCategories() {
    state = state.copyWith(
      selectedCategories: const [],
      selectedInterests: const {},
      clearError: true,
    );
  }

  void toggleInterest(String categoryKey, String interestKey) {
    final current = <String>[
      ...(state.selectedInterests[categoryKey] ?? const []),
    ];
    if (current.contains(interestKey)) {
      current.remove(interestKey);
    } else {
      if (current.length >= OnboardingCaps.interestsPerCategory) return;
      current.add(interestKey);
    }
    state = state.copyWith(
      selectedInterests: {...state.selectedInterests, categoryKey: current},
      clearError: true,
    );
  }

  void clearInterests(String categoryKey) {
    state = state.copyWith(
      selectedInterests: {...state.selectedInterests, categoryKey: const []},
      clearError: true,
    );
  }

  void addCustomInterest(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 40) return;
    if (state.customInterests.contains(trimmed)) return;
    if (state.customInterests.length >= OnboardingCaps.customInterests) return;
    state = state.copyWith(
      customInterests: [...state.customInterests, trimmed],
      clearError: true,
    );
  }

  void removeCustomInterest(String text) {
    state = state.copyWith(
      customInterests: state.customInterests.where((c) => c != text).toList(),
    );
  }

  /// Saves step 2 once the grid + detail screens are done.
  /// Returns true on success so the screen can advance.
  Future<bool> saveInterests() => _save(
    () => _repo.saveInterests(
      interestCategories: state.selectedCategories,
      interests: state.allInterests,
      customInterests: state.customInterests,
    ),
  );

  // ── Step 3: colours ───────────────────────────────────────────────────────

  void toggleColor(String key) {
    final selected = [...state.selectedColors];
    if (selected.contains(key)) {
      selected.remove(key);
    } else {
      if (selected.length >= OnboardingCaps.colors) return;
      selected.add(key);
    }
    state = state.copyWith(selectedColors: selected, clearError: true);
  }

  void clearColors() =>
      state = state.copyWith(selectedColors: const [], clearError: true);

  Future<bool> saveColors() =>
      _save(() => _repo.saveColors(state.selectedColors));

  // ── Step 4: size & fit ────────────────────────────────────────────────────

  void setClothingSize(String key) => state = state.copyWith(
    clothingSize: state.clothingSize == key ? null : key,
    clearClothing: state.clothingSize == key,
    clearError: true,
  );

  void setShoeSystem(String system) {
    // Sizes do not translate across systems, so switching resets the pick.
    state = state.copyWith(
      shoeSystem: system,
      clearShoe: true,
      clearError: true,
    );
  }

  void setShoeSize(String key) => state = state.copyWith(
    shoeSize: state.shoeSize == key ? null : key,
    clearShoe: state.shoeSize == key,
    clearError: true,
  );

  void setFitPreference(String key) => state = state.copyWith(
    fitPreference: state.fitPreference == key ? null : key,
    clearFit: state.fitPreference == key,
    clearError: true,
  );

  void clearSizes() => state = state.copyWith(
    clearClothing: true,
    clearShoe: true,
    clearFit: true,
    clearError: true,
  );

  Future<bool> saveSizes() => _save(
    () => _repo.saveSizes(
      clothingSize: state.clothingSize,
      shoeSize: state.shoeSize,
      fitPreference: state.fitPreference,
    ),
  );

  // ── Step 5: important dates ───────────────────────────────────────────────

  /// Saves one date immediately (the design's per-entry "Save Date" button).
  Future<bool> addDate({
    required String personName,
    required String relation,
    required String occasionKey,
    required String dateIso,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final saved = await _repo.addImportantDate(
        personName: personName,
        relation: relation,
        occasionKey: occasionKey,
        dateIso: dateIso,
      );
      state = state.copyWith(
        busy: false,
        savedDates: [...state.savedDates, saved],
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    }
  }

  Future<void> removeDate(String id) async {
    try {
      await _repo.removeImportantDate(id);
      state = state.copyWith(
        savedDates: state.savedDates.where((d) => d.id != id).toList(),
      );
    } on ApiException catch (e) {
      state = state.copyWith(error: _message(e));
    }
  }

  // ── Finish ────────────────────────────────────────────────────────────────

  /// `POST /onboarding/complete`; already-complete counts as success.
  Future<bool> finish() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _repo.complete();
      state = state.copyWith(busy: false, finished: true);
      return true;
    } on ApiException catch (e) {
      if (e.code == 'ONBOARDING_ALREADY_COMPLETE') {
        state = state.copyWith(busy: false, finished: true);
        return true;
      }
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    }
  }

  Future<bool> _save(Future<Object?> Function() call) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await call();
      state = state.copyWith(busy: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    }
  }

  static String _message(ApiException e) => switch (e.code) {
    'TAXONOMY_VALUE_INVALID' =>
      'Some options are out of date — pull to refresh and try again.',
    ApiException.codeNetwork ||
    ApiException.codeTimeout => 'No connection. Check your network and retry.',
    _ => e.message,
  };
}

final onboardingFlowProvider =
    NotifierProvider<OnboardingFlowController, OnboardingFlowState>(
      OnboardingFlowController.new,
    );
