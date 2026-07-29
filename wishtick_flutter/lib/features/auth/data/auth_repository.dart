import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/token_storage.dart';
import '../domain/auth_user.dart';

/// A successful authentication: the user plus the token pair to store.
class AuthResult {
  const AuthResult({
    required this.user,
    required this.tokens,
    this.isNewUser = false,
  });

  final AuthUser user;
  final AuthTokens tokens;

  /// True when this call created the account, which is what routes a user into
  /// onboarding rather than straight to home.
  final bool isNewUser;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    tokens: AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
    isNewUser: json['isNewUser'] as bool? ?? false,
  );
}

/// Talks to the backend's `auth` module.
///
/// Endpoint shapes come from `wishtick_backend/src/modules/auth`:
///  * `POST /auth/otp/request` + `/auth/otp/verify` are the passwordless phone
///    flow the design is built around — verify returns `{user, tokens,
///    isNewUser}` and creates the account on first use
///  * `POST /auth/signup` and `/auth/login` are the password flow, kept for
///    accounts that set a password via the reset link
///  * `/auth/verify/phone/*` mark an *existing* user's number verified and do
///    **not** issue tokens; the OTP sign-in flow verifies the number implicitly
///  * OTP codes are 6 digits, valid 10 minutes, 5 attempts, 60s resend cooldown
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// OTP parameters, mirrored from the backend config so the UI can show an
  /// accurate resend countdown and code length without guessing.
  static const otpLength = 6;
  static const otpResendCooldown = Duration(seconds: 60);
  static const otpValidity = Duration(minutes: 10);
  static const otpMaxAttempts = 5;

  /// Sends a sign-in code to [phone], whether or not it is registered.
  ///
  /// Returns how long the code stays valid, so the UI can show an accurate
  /// expiry rather than assuming.
  Future<Duration> requestSignInCode(String phone) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/otp/request',
      body: {'phone': phone},
    );
    final seconds = json['expiresInSeconds'] as int?;
    return seconds == null ? otpValidity : Duration(seconds: seconds);
  }

  /// Exchanges a sign-in code for a session, creating the account if the number
  /// is new. [name] is applied only when this call creates the account.
  Future<AuthResult> verifySignInCode({
    required String phone,
    required String code,
    String? name,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/otp/verify',
      body: {
        'phone': phone,
        'code': code,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
    return AuthResult.fromJson(json);
  }

  Future<AuthResult> signup({
    required String password,
    String? email,
    String? phone,
    String? name,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/signup',
      body: {
        'password': password,
        'email': ?email,
        'phone': ?phone,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
    return AuthResult.fromJson(json);
  }

  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: {'identifier': identifier, 'password': password},
    );
    return AuthResult.fromJson(json);
  }

  /// Sends a verification code by SMS.
  ///
  /// Responds identically whether or not the number is registered, so it leaks
  /// nothing about who has an account.
  Future<void> requestPhoneVerification(String phone) {
    return _api.post<Map<String, dynamic>>(
      '/auth/verify/phone/request',
      body: {'phone': phone},
    );
  }

  /// Confirms an SMS code, marking the number verified.
  ///
  /// Note this returns no session — see [AuthRepository] docs.
  Future<void> confirmPhoneVerification({
    required String phone,
    required String code,
  }) {
    return _api.post<Map<String, dynamic>>(
      '/auth/verify/phone/confirm',
      body: {'phone': phone, 'code': code},
    );
  }

  Future<AuthUser> me() async {
    final json = await _api.get<Map<String, dynamic>>('/auth/me');
    return AuthUser.fromJson(json);
  }

  Future<void> logout() => _api.post<void>('/auth/logout');
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
