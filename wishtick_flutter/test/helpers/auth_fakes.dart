import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/features/auth/data/auth_repository.dart';
import 'package:wishtick_flutter/features/auth/domain/auth_user.dart';

AuthUser buildUser({
  String id = 'user_1',
  String? phone = '+919876543210',
  String? name = 'Ananya',
  bool phoneVerified = true,
}) {
  return AuthUser(
    id: id,
    phone: phone,
    name: name,
    emailVerified: false,
    phoneVerified: phoneVerified,
    roles: const ['user'],
    createdAt: DateTime.utc(2026, 7, 1),
  );
}

/// In-memory stand-in for the platform keystore.
class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage({String? accessToken, String? refreshToken})
    : _access = accessToken,
      _refresh = refreshToken;

  String? _access;
  String? _refresh;

  int saveCount = 0;
  int clearCount = 0;

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> save(AuthTokens tokens) async {
    saveCount++;
    _access = tokens.accessToken;
    _refresh = tokens.refreshToken;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    _access = null;
    _refresh = null;
  }

  @override
  Future<bool> get hasSession async => _refresh != null;
}

/// Scriptable stand-in for the auth API.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user, this.meFailure});

  AuthUser? user;

  /// When set, `me()` throws this instead of returning [user].
  ApiException? meFailure;

  int meCalls = 0;
  int logoutCalls = 0;
  final requestedOtpFor = <String>[];
  final confirmedOtps = <({String phone, String code})>[];

  /// Codes the sign-in flow was asked to send, and the verifications attempted.
  final requestedSignInFor = <String>[];
  final verifiedSignIns = <({String phone, String code, String? name})>[];

  /// When set, the next `requestSignInCode` throws this.
  ApiException? requestCodeFailure;

  /// When set, the next `verifySignInCode` throws this.
  ApiException? verifyCodeFailure;

  /// What `verifySignInCode` reports for a successful verification.
  bool nextIsNewUser = false;

  @override
  Future<AuthUser> me() async {
    meCalls++;
    final failure = meFailure;
    if (failure != null) throw failure;
    return user ?? buildUser();
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<Duration> requestSignInCode(String phone) async {
    requestedSignInFor.add(phone);
    final failure = requestCodeFailure;
    if (failure != null) throw failure;
    return AuthRepository.otpValidity;
  }

  @override
  Future<AuthResult> verifySignInCode({
    required String phone,
    required String code,
    String? name,
  }) async {
    verifiedSignIns.add((phone: phone, code: code, name: name));
    final failure = verifyCodeFailure;
    if (failure != null) throw failure;
    return AuthResult(
      user: user ?? buildUser(phone: phone, name: name),
      tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
      isNewUser: nextIsNewUser,
    );
  }

  @override
  Future<void> requestPhoneVerification(String phone) async {
    requestedOtpFor.add(phone);
  }

  @override
  Future<void> confirmPhoneVerification({
    required String phone,
    required String code,
  }) async {
    confirmedOtps.add((phone: phone, code: code));
  }

  @override
  Future<AuthResult> signup({
    required String password,
    String? email,
    String? phone,
    String? name,
  }) async {
    return AuthResult(
      user: user ?? buildUser(phone: phone, name: name),
      tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
  }

  @override
  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    return AuthResult(
      user: user ?? buildUser(),
      tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
  }
}
