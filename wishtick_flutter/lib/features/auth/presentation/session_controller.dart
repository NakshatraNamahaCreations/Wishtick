import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/token_storage.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

/// Where the app is in the sign-in lifecycle.
enum SessionStatus {
  /// Startup: we have not yet decided whether a stored session is usable.
  unknown,
  authenticated,
  unauthenticated,
}

@immutable
class SessionState {
  const SessionState({
    required this.status,
    this.user,
    this.onboardingCompleted = false,
  });

  const SessionState.unknown()
    : status = SessionStatus.unknown,
      user = null,
      onboardingCompleted = false;
  const SessionState.signedOut()
    : status = SessionStatus.unauthenticated,
      user = null,
      onboardingCompleted = false;

  final SessionStatus status;
  final AuthUser? user;

  /// Whether the 5-step onboarding is finished. The router keeps a signed-in
  /// user inside onboarding until it is.
  final bool onboardingCompleted;

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isResolved => status != SessionStatus.unknown;

  @override
  bool operator ==(Object other) =>
      other is SessionState &&
      other.status == status &&
      other.user == user &&
      other.onboardingCompleted == onboardingCompleted;

  @override
  int get hashCode => Object.hash(status, user, onboardingCompleted);
}

/// Owns the signed-in user and the stored tokens.
///
/// Everything that changes sign-in state goes through here so there is exactly
/// one place that writes tokens, and one source of truth for the router.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState.unknown();

  TokenStorage get _tokens => ref.read(tokenStorageProvider);
  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// Resolves the stored session on startup: if a refresh token survives, ask
  /// the server who we are. Any failure lands on signed-out rather than
  /// stranding the app in [SessionStatus.unknown].
  Future<void> restore() async {
    if (!await _tokens.hasSession) {
      state = const SessionState.signedOut();
      return;
    }

    try {
      final user = await _auth.me();
      state = SessionState(
        status: SessionStatus.authenticated,
        user: user,
        onboardingCompleted: await _isOnboardingComplete(),
      );
    } on ApiException {
      // Includes the case where the interceptor already tried to refresh and
      // the refresh token was spent or revoked.
      await _tokens.clear();
      state = const SessionState.signedOut();
    }
  }

  /// Stores the tokens from a successful signup/login and marks the user in.
  Future<void> accept(AuthResult result) async {
    await _tokens.save(result.tokens);
    state = SessionState(
      status: SessionStatus.authenticated,
      user: result.user,
      // A brand-new account has no onboarding progress by definition, so skip
      // the round trip and send them straight into step 1.
      onboardingCompleted: result.isNewUser
          ? false
          : await _isOnboardingComplete(),
    );
  }

  /// Marks onboarding finished locally, so the router releases the user into the
  /// app without waiting for another status fetch.
  void markOnboardingComplete() {
    if (!state.isAuthenticated) return;
    state = SessionState(
      status: SessionStatus.authenticated,
      user: state.user,
      onboardingCompleted: true,
    );
  }

  /// Defaults to *complete* when the status cannot be read: letting someone into
  /// the app on a failed request is recoverable, trapping them in onboarding is
  /// not.
  Future<bool> _isOnboardingComplete() async {
    try {
      return (await ref.read(onboardingRepositoryProvider).status()).completed;
    } on ApiException {
      return true;
    }
  }

  /// Replaces the cached user without touching tokens — after editing a
  /// profile, or once a phone number is verified.
  void updateUser(AuthUser user) {
    if (!state.isAuthenticated) return;
    state = SessionState(status: SessionStatus.authenticated, user: user);
  }

  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;
    try {
      updateUser(await _auth.me());
    } on ApiException {
      // A stale cached user is better than bouncing someone out of the app.
    }
  }

  Future<void> signOut() async {
    // Best-effort: revoking server-side is desirable but must never block the
    // local sign-out, or a network failure would trap the user in the app.
    try {
      await _auth.logout();
    } on ApiException {
      // Ignored deliberately.
    }
    await _tokens.clear();
    state = const SessionState.signedOut();
  }

  /// Deletes the account, then signs out locally (`64:158`).
  ///
  /// The order matters: the delete needs a live token, so it goes first, and
  /// the local sign-out follows unconditionally — once the server has removed
  /// the account, holding on to its tokens would leave the app pointed at a
  /// user that no longer exists.
  Future<void> deleteAccount() async {
    try {
      await ref.read(profileRepositoryProvider).deleteAccount();
    } on ApiException {
      // Ignored deliberately, as in [signOut]: nothing useful can be done from
      // here, and stranding a signed-in session is worse.
    }
    await _tokens.clear();
    state = const SessionState.signedOut();
  }

  /// Called by the network layer when a refresh token is rejected mid-flight.
  Future<void> onExpired() async {
    await _tokens.clear();
    state = const SessionState.signedOut();
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Overrides the network layer's session-expiry hook so a rejected refresh
/// signs the user out and the router reacts.
///
/// Applied in `main()` rather than declared inside `core/network`, which keeps
/// the network layer free of feature imports.
final sessionExpiryOverride = onSessionExpiredProvider.overrideWith(
  (ref) =>
      () => ref.read(sessionProvider.notifier).onExpired(),
);
