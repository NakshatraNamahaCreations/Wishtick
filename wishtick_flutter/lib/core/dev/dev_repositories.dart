import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../features/onboarding/domain/onboarding_options.dart';
import '../../features/onboarding/domain/profile_draft.dart';
import '../network/token_storage.dart';
import 'dev_taxonomy.dart';

/// Keys the fakes persist under, so a restart behaves like a real session
/// rather than resetting the app to a blank slate every launch.
abstract final class _DevKeys {
  static const phone = 'wishtick.dev.phone';
  static const name = 'wishtick.dev.name';
  static const onboardingComplete = 'wishtick.dev.onboarding_complete';
  static const dates = 'wishtick.dev.dates';
}

/// Accepts any phone number and any correctly-sized code.
///
/// Real tokens are still written through [TokenStorage] by the session
/// controller, so sign-in survives a restart exactly as it will in production —
/// the only thing faked is the server's answer.
class DevAuthRepository implements AuthRepository {
  DevAuthRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Enough delay to see the button's spinner; short enough not to annoy.
  static const _latency = Duration(milliseconds: 400);

  AuthUser _user() => AuthUser(
    id: 'dev-user',
    phone: _prefs.getString(_DevKeys.phone) ?? '+910000000000',
    name: _prefs.getString(_DevKeys.name),
    emailVerified: false,
    phoneVerified: true,
    roles: const ['user'],
    createdAt: DateTime.now(),
  );

  @override
  Future<Duration> requestSignInCode(String phone) async {
    await Future<void>.delayed(_latency);
    await _prefs.setString(_DevKeys.phone, phone);
    return AuthRepository.otpValidity;
  }

  @override
  Future<AuthResult> verifySignInCode({
    required String phone,
    required String code,
    String? name,
  }) async {
    await Future<void>.delayed(_latency);
    await _prefs.setString(_DevKeys.phone, phone);
    if (name != null) await _prefs.setString(_DevKeys.name, name);

    return AuthResult(
      user: _user(),
      tokens: const AuthTokens(
        accessToken: 'dev-access',
        refreshToken: 'dev-refresh',
      ),
      // A signed-in dev user goes through onboarding until they finish it once;
      // after that a restart lands on Home, like a returning user.
      isNewUser: !(_prefs.getBool(_DevKeys.onboardingComplete) ?? false),
    );
  }

  @override
  Future<AuthUser> me() async {
    await Future<void>.delayed(_latency);
    return _user();
  }

  @override
  Future<void> logout() async {
    await _prefs.remove(_DevKeys.onboardingComplete);
    await _prefs.remove(_DevKeys.dates);
  }

  // The password flow is not reachable from the UI; the fake refuses it rather
  // than pretending, so nobody builds on a path that does not exist.
  @override
  Future<AuthResult> signup({
    required String password,
    String? email,
    String? phone,
    String? name,
  }) => throw UnimplementedError('Password signup is not part of the dev flow');

  @override
  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) => throw UnimplementedError('Password login is not part of the dev flow');

  @override
  Future<void> requestPhoneVerification(String phone) async {}

  @override
  Future<void> confirmPhoneVerification({
    required String phone,
    required String code,
  }) async {}
}

/// Serves the real taxonomy shape from memory and accepts every step save.
class DevOnboardingRepository implements OnboardingRepository {
  DevOnboardingRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _latency = Duration(milliseconds: 300);

  bool get _complete => _prefs.getBool(_DevKeys.onboardingComplete) ?? false;

  OnboardingStatus _status() => OnboardingStatus(
    completed: _complete,
    completedSteps: _complete ? const ['profile'] : const [],
    remainingRequiredSteps: _complete ? const [] : const ['profile'],
  );

  @override
  Future<OnboardingStatus> status() async {
    await Future<void>.delayed(_latency);
    return _status();
  }

  @override
  Future<OnboardingOptions> options() async {
    await Future<void>.delayed(_latency);
    return DevTaxonomy.build();
  }

  @override
  Future<OnboardingStatus> saveProfile(ProfileDraft draft) async {
    await Future<void>.delayed(_latency);
    if (draft.hasName) await _prefs.setString(_DevKeys.name, draft.name.trim());
    return _status();
  }

  @override
  Future<OnboardingStatus> saveInterests({
    required List<String> interestCategories,
    required List<String> interests,
    required List<String> customInterests,
  }) async {
    await Future<void>.delayed(_latency);
    return _status();
  }

  @override
  Future<OnboardingStatus> saveColors(List<String> favouriteColors) async {
    await Future<void>.delayed(_latency);
    return _status();
  }

  @override
  Future<OnboardingStatus> saveSizes({
    String? clothingSize,
    String? shoeSize,
    String? fitPreference,
  }) async {
    await Future<void>.delayed(_latency);
    return _status();
  }

  @override
  Future<OnboardingStatus> complete() async {
    await Future<void>.delayed(_latency);
    await _prefs.setBool(_DevKeys.onboardingComplete, true);
    return _status();
  }

  // ── Important dates, persisted as JSON rows ───────────────────────────────
  // JSON rather than a delimited string: names are free text and would break
  // any separator we picked.

  List<ImportantDate> _readDates() {
    return (_prefs.getStringList(_DevKeys.dates) ?? const [])
        .map(
          (row) =>
              ImportantDate.fromJson(jsonDecode(row) as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> _writeDates(List<ImportantDate> dates) =>
      _prefs.setStringList(_DevKeys.dates, [
        for (final d in dates)
          jsonEncode({
            'id': d.id,
            'personName': d.personName,
            'relation': d.relation,
            'occasionKey': d.occasionKey,
            'date': d.date,
          }),
      ]);

  @override
  Future<List<ImportantDate>> listImportantDates() async {
    await Future<void>.delayed(_latency);
    return _readDates();
  }

  @override
  Future<ImportantDate> addImportantDate({
    required String personName,
    required String relation,
    required String occasionKey,
    required String dateIso,
  }) async {
    await Future<void>.delayed(_latency);
    final dates = _readDates();
    final saved = ImportantDate(
      id: 'dev-${dates.length + 1}',
      personName: personName,
      relation: relation,
      occasionKey: occasionKey,
      date: dateIso,
    );
    await _writeDates([...dates, saved]);
    return saved;
  }

  @override
  Future<void> removeImportantDate(String id) async {
    await _writeDates(_readDates().where((d) => d.id != id).toList());
  }
}
