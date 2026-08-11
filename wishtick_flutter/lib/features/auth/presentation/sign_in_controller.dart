import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../domain/phone_number.dart';
import 'session_controller.dart';

/// Which step of the passwordless flow the user is on.
enum SignInStep { phone, code }

@immutable
class SignInState {
  const SignInState({
    required this.phone,
    this.step = SignInStep.phone,
    this.name,
    this.busy = false,
    this.error,
    this.resendIn = Duration.zero,
    this.codeExpiresIn,
    this.attemptsRemaining,
    this.completed = false,
    this.isNewUser = false,
    this.acceptedTerms = false,
    this.marketingOptIn = false,
  });

  const SignInState.initial()
    : phone = null,
      step = SignInStep.phone,
      name = null,
      busy = false,
      error = null,
      resendIn = Duration.zero,
      codeExpiresIn = null,
      attemptsRemaining = null,
      completed = false,
      isNewUser = false,
      acceptedTerms = false,
      marketingOptIn = false;

  final PhoneNumber? phone;
  final SignInStep step;

  /// Collected before the number on the create-account screen; sent with the
  /// verification so a brand-new account is named from the start.
  final String? name;

  final bool busy;

  /// User-facing message for the current failure, or null.
  final String? error;

  /// Counts down to when "Resend code" becomes available again.
  final Duration resendIn;

  final Duration? codeExpiresIn;

  /// Reported by the API after a wrong code, so the UI can warn before lockout.
  final int? attemptsRemaining;

  final bool completed;
  final bool isNewUser;

  /// Ticking the Terms box is what unlocks "GET OTP". Starts **false**: a
  /// pre-ticked consent box is not consent under the DPDP Act or the GDPR, so
  /// the user has to act.
  final bool acceptedTerms;

  /// Optional promotional email opt-in. Collected here, but see the note on
  /// [SignInController.setMarketingOptIn] — the API has nowhere to put it yet.
  final bool marketingOptIn;

  bool get canResend => resendIn == Duration.zero && !busy;

  /// Everything the phone step needs before it may ask for a code.
  bool get canRequestCode => (phone?.isComplete ?? false) && acceptedTerms;

  SignInState copyWith({
    PhoneNumber? phone,
    SignInStep? step,
    String? name,
    bool? busy,
    Duration? resendIn,
    Duration? codeExpiresIn,
    int? attemptsRemaining,
    bool? completed,
    bool? isNewUser,
    bool? acceptedTerms,
    bool? marketingOptIn,
    bool clearError = false,
    String? error,
  }) {
    return SignInState(
      phone: phone ?? this.phone,
      step: step ?? this.step,
      name: name ?? this.name,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      resendIn: resendIn ?? this.resendIn,
      codeExpiresIn: codeExpiresIn ?? this.codeExpiresIn,
      attemptsRemaining: attemptsRemaining ?? this.attemptsRemaining,
      completed: completed ?? this.completed,
      isNewUser: isNewUser ?? this.isNewUser,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
    );
  }
}

/// Drives the passwordless phone sign-in: request a code, then exchange it for
/// a session.
class SignInController extends Notifier<SignInState> {
  Timer? _resendTimer;

  @override
  SignInState build() {
    ref.onDispose(() => _resendTimer?.cancel());
    return const SignInState.initial();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  void setName(String name) {
    state = state.copyWith(name: name.trim(), clearError: true);
  }

  void setPhone(PhoneNumber phone) {
    state = state.copyWith(phone: phone, clearError: true);
  }

  void setAcceptedTerms(bool value) {
    state = state.copyWith(acceptedTerms: value, clearError: true);
  }

  /// Records the promotional-email preference.
  ///
  /// It goes no further than this object today: the sign-in API takes only a
  /// phone number, and no user field exists to hold it. Wire it into the
  /// profile once the backend grows a marketing-consent field — until then a
  /// user who opts in here is not yet subscribed anywhere.
  void setMarketingOptIn(bool value) {
    state = state.copyWith(marketingOptIn: value);
  }

  /// Sends the code and advances to the code step.
  Future<void> requestCode() async {
    final phone = state.phone;
    // Terms included: the button is disabled without them, but a stray Enter
    // on the keyboard reaches here too.
    if (phone == null || !state.canRequestCode || state.busy) return;

    state = state.copyWith(busy: true, clearError: true);
    try {
      final validity = await _auth.requestSignInCode(phone.e164);
      state = state.copyWith(
        busy: false,
        step: SignInStep.code,
        codeExpiresIn: validity,
        attemptsRemaining: null,
      );
      _startResendCountdown();
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _messageFor(e));
      // A cooldown rejection still tells us how long to wait.
      final retryAfter = _retryAfterOf(e);
      if (retryAfter != null) _startResendCountdown(retryAfter);
    }
  }

  Future<void> resendCode() async {
    if (!state.canResend) return;
    await requestCode();
  }

  /// Verifies [code]; on success the session is stored and [SignInState.completed]
  /// flips, which the screen watches to navigate on.
  Future<void> submitCode(String code) async {
    final phone = state.phone;
    if (phone == null || state.busy) return;
    if (code.length != AuthRepository.otpLength) return;

    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await _auth.verifySignInCode(
        phone: phone.e164,
        code: code,
        name: state.name,
      );
      await ref.read(sessionProvider.notifier).accept(result);
      state = state.copyWith(
        busy: false,
        completed: true,
        isNewUser: result.isNewUser,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        busy: false,
        error: _messageFor(e),
        attemptsRemaining: _attemptsRemainingOf(e),
      );
    }
  }

  /// Back from the code step to correct the number.
  void editPhone() {
    _resendTimer?.cancel();
    state = state.copyWith(
      step: SignInStep.phone,
      resendIn: Duration.zero,
      attemptsRemaining: null,
      clearError: true,
    );
  }

  void _startResendCountdown([Duration? from]) {
    _resendTimer?.cancel();
    state = state.copyWith(resendIn: from ?? AuthRepository.otpResendCooldown);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.resendIn - const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        timer.cancel();
        state = state.copyWith(resendIn: Duration.zero);
      } else {
        state = state.copyWith(resendIn: remaining);
      }
    });
  }

  /// The backend documents `error.code` as the thing to branch on — never the
  /// message — so every user-facing string is chosen here.
  static String _messageFor(ApiException e) => switch (e.code) {
    'OTP_INVALID' => 'That code is incorrect.',
    'OTP_EXPIRED' =>
      'That code has expired or was already used. Request a new one.',
    'OTP_MAX_ATTEMPTS' =>
      'Too many incorrect attempts. Request a new code to try again.',
    'OTP_COOLDOWN' => 'Please wait before requesting another code.',
    'ACCOUNT_SUSPENDED' => e.message,
    'ACCOUNT_DELETED' => e.message,
    'VALIDATION_FAILED' => 'Please check the number and try again.',
    ApiException.codeNetwork ||
    ApiException.codeTimeout => 'No connection. Check your network and retry.',
    _ => e.message,
  };

  static int? _attemptsRemainingOf(ApiException e) {
    final details = e.details;
    if (details is Map && details['attemptsRemaining'] is int) {
      return details['attemptsRemaining'] as int;
    }
    return null;
  }

  static Duration? _retryAfterOf(ApiException e) {
    final details = e.details;
    if (details is Map && details['retryAfterSeconds'] is int) {
      return Duration(seconds: details['retryAfterSeconds'] as int);
    }
    return null;
  }
}

/// Auto-disposed (the Riverpod 3 default), so leaving the flow discards any
/// half-entered number, pending countdown and error.
final signInControllerProvider =
    NotifierProvider<SignInController, SignInState>(SignInController.new);
