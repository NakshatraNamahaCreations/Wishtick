import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/network/token_storage.dart';
import 'package:wishtick_flutter/features/auth/data/auth_repository.dart';
import 'package:wishtick_flutter/features/auth/domain/phone_number.dart';
import 'package:wishtick_flutter/features/auth/presentation/session_controller.dart';
import 'package:wishtick_flutter/features/auth/presentation/sign_in_controller.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/onboarding_fakes.dart';

void main() {
  /// Well-formed codes, whatever length the backend uses.
  ///
  /// These were the literals '1234' / '0000', which stopped being valid codes
  /// the day `otpLength` was corrected from 4 to 6 — every test here then
  /// failed for that reason alone. Deriving them means a future change to the
  /// contract cannot strand them again.
  final validCode = '1' * AuthRepository.otpLength;
  final wrongCode = '0' * AuthRepository.otpLength;
  final tooShort = '1' * (AuthRepository.otpLength - 1);

  ({
    ProviderContainer container,
    FakeAuthRepository auth,
    FakeTokenStorage tokens,
  })
  build() {
    final auth = FakeAuthRepository();
    final tokens = FakeTokenStorage();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        tokenStorageProvider.overrideWithValue(tokens),
        // The session's onboarding check would otherwise reach the real network
        // and stall each test on the connect timeout.
        onboardingRepositoryProvider.overrideWithValue(
          FakeOnboardingRepository(completed: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, auth: auth, tokens: tokens);
  }

  SignInController controllerOf(ProviderContainer c) =>
      c.read(signInControllerProvider.notifier);
  SignInState stateOf(ProviderContainer c) => c.read(signInControllerProvider);

  const validPhone = '9876543210';

  group('requesting a code', () {
    test('sends the E.164 number and moves to the code step', () async {
      final t = build();
      controllerOf(t.container).setPhone(PhoneNumber.parse(validPhone));
      controllerOf(t.container).setAcceptedTerms(true);

      await controllerOf(t.container).requestCode();

      expect(t.auth.requestedSignInFor, ['+919876543210']);
      expect(stateOf(t.container).step, SignInStep.code);
      expect(stateOf(t.container).busy, isFalse);
    });

    test('does nothing for an incomplete number', () async {
      final t = build();
      controllerOf(t.container).setPhone(PhoneNumber.parse('98765'));

      await controllerOf(t.container).requestCode();

      expect(t.auth.requestedSignInFor, isEmpty);
      expect(stateOf(t.container).step, SignInStep.phone);
    });

    test('starts the resend countdown so the button locks out', () async {
      final t = build();
      controllerOf(t.container).setPhone(PhoneNumber.parse(validPhone));
      controllerOf(t.container).setAcceptedTerms(true);

      await controllerOf(t.container).requestCode();

      expect(stateOf(t.container).resendIn, AuthRepository.otpResendCooldown);
      expect(stateOf(t.container).canResend, isFalse);
    });

    test(
      'surfaces a cooldown rejection and honours its retry window',
      () async {
        final t = build()
          ..auth.requestCodeFailure = const ApiException(
            code: 'OTP_COOLDOWN',
            message: 'Please wait 42s',
            statusCode: 429,
            details: {'retryAfterSeconds': 42},
          );
        controllerOf(t.container).setPhone(PhoneNumber.parse(validPhone));
        controllerOf(t.container).setAcceptedTerms(true);

        await controllerOf(t.container).requestCode();

        final state = stateOf(t.container);
        expect(state.step, SignInStep.phone);
        expect(state.error, 'Please wait before requesting another code.');
        expect(state.resendIn, const Duration(seconds: 42));
      },
    );

    test('reports a network failure in plain language', () async {
      final t = build()
        ..auth.requestCodeFailure = const ApiException(
          code: ApiException.codeNetwork,
          message: 'No internet connection.',
        );
      controllerOf(t.container).setPhone(PhoneNumber.parse(validPhone));
      controllerOf(t.container).setAcceptedTerms(true);

      await controllerOf(t.container).requestCode();

      expect(
        stateOf(t.container).error,
        'No connection. Check your network and retry.',
      );
    });
  });

  group('submitting a code', () {
    Future<ProviderContainer> atCodeStep(
      ({
        ProviderContainer container,
        FakeAuthRepository auth,
        FakeTokenStorage tokens,
      })
      t, {
      String? name,
    }) async {
      final controller = controllerOf(t.container);
      if (name != null) controller.setName(name);
      controller.setPhone(PhoneNumber.parse(validPhone));
      controller.setAcceptedTerms(true);
      await controller.requestCode();
      return t.container;
    }

    test('stores the session and completes', () async {
      final t = build();
      await atCodeStep(t);

      await controllerOf(t.container).submitCode(validCode);

      expect(t.auth.verifiedSignIns.single.code, validCode);
      expect(stateOf(t.container).completed, isTrue);
      expect(t.tokens.saveCount, 1);
      expect(
        t.container.read(sessionProvider).status,
        SessionStatus.authenticated,
      );
    });

    test('passes the collected name so a new account is named', () async {
      final t = build();
      await atCodeStep(t, name: 'Ananya');

      await controllerOf(t.container).submitCode(validCode);

      expect(t.auth.verifiedSignIns.single.name, 'Ananya');
    });

    test('reports whether the account was just created', () async {
      final t = build()..auth.nextIsNewUser = true;
      await atCodeStep(t);

      await controllerOf(t.container).submitCode(validCode);

      expect(stateOf(t.container).isNewUser, isTrue);
    });

    test('ignores a code of the wrong length', () async {
      final t = build();
      await atCodeStep(t);

      await controllerOf(t.container).submitCode(tooShort);

      expect(t.auth.verifiedSignIns, isEmpty);
      expect(stateOf(t.container).completed, isFalse);
    });

    test('shows the attempts left after a wrong code', () async {
      final t = build();
      await atCodeStep(t);
      t.auth.verifyCodeFailure = const ApiException(
        code: 'OTP_INVALID',
        message: 'Incorrect code',
        statusCode: 400,
        details: {'attemptsRemaining': 3},
      );

      await controllerOf(t.container).submitCode(wrongCode);

      final state = stateOf(t.container);
      expect(state.error, 'That code is incorrect.');
      expect(state.attemptsRemaining, 3);
      expect(state.completed, isFalse);
      // A failed attempt must not sign anyone in.
      expect(t.container.read(sessionProvider).status, SessionStatus.unknown);
    });

    test('explains an expired code', () async {
      final t = build();
      await atCodeStep(t);
      t.auth.verifyCodeFailure = const ApiException(
        code: 'OTP_EXPIRED',
        message: 'expired',
        statusCode: 400,
      );

      await controllerOf(t.container).submitCode(wrongCode);

      expect(
        stateOf(t.container).error,
        'That code has expired or was already used. Request a new one.',
      );
    });

    test('explains lockout after too many attempts', () async {
      final t = build();
      await atCodeStep(t);
      t.auth.verifyCodeFailure = const ApiException(
        code: 'OTP_MAX_ATTEMPTS',
        message: 'too many',
        statusCode: 429,
      );

      await controllerOf(t.container).submitCode(wrongCode);

      expect(
        stateOf(t.container).error,
        'Too many incorrect attempts. Request a new code to try again.',
      );
    });

    test('passes a suspension message through verbatim', () async {
      final t = build();
      await atCodeStep(t);
      t.auth.verifyCodeFailure = const ApiException(
        code: 'ACCOUNT_SUSPENDED',
        message: 'This account is suspended: spam',
        statusCode: 403,
      );

      await controllerOf(t.container).submitCode(wrongCode);

      expect(stateOf(t.container).error, 'This account is suspended: spam');
    });
  });

  group('editing the number', () {
    test('returns to the phone step and clears the countdown', () async {
      final t = build();
      controllerOf(t.container).setPhone(PhoneNumber.parse(validPhone));
      controllerOf(t.container).setAcceptedTerms(true);
      await controllerOf(t.container).requestCode();

      controllerOf(t.container).editPhone();

      final state = stateOf(t.container);
      expect(state.step, SignInStep.phone);
      expect(state.resendIn, Duration.zero);
      expect(state.error, isNull);
      // The number is kept so the field is pre-filled for correction.
      expect(state.phone?.nationalNumber, validPhone);
    });
  });
}
