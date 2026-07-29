import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/auth/domain/phone_number.dart';

void main() {
  group('PhoneNumber.parse', () {
    test('keeps plain national digits', () {
      final phone = PhoneNumber.parse('9876543210');
      expect(phone.dialCode, '+91');
      expect(phone.nationalNumber, '9876543210');
      expect(phone.e164, '+919876543210');
    });

    test('strips the punctuation the backend strips', () {
      expect(PhoneNumber.parse('98765 43210').e164, '+919876543210');
      expect(PhoneNumber.parse('(98765) 43210').e164, '+919876543210');
      expect(PhoneNumber.parse('98765-43210').e164, '+919876543210');
    });

    test('drops the national trunk zero', () {
      expect(PhoneNumber.parse('09876543210').nationalNumber, '9876543210');
    });

    test('accepts a number typed with its country code', () {
      expect(PhoneNumber.parse('+919876543210').nationalNumber, '9876543210');
      expect(PhoneNumber.parse('919876543210').nationalNumber, '9876543210');
    });

    test('never exceeds the national length', () {
      expect(PhoneNumber.parse('98765432109999').nationalNumber.length, 10);
    });

    test('ignores letters and stray symbols', () {
      expect(PhoneNumber.parse('98a76b54321c0').nationalNumber, '9876543210');
    });
  });

  group('validation', () {
    test('a full Indian mobile number is complete and valid', () {
      final phone = PhoneNumber.parse('9876543210');
      expect(phone.isComplete, isTrue);
      expect(phone.isValid, isTrue);
    });

    test('a partial number is not complete', () {
      final phone = PhoneNumber.parse('98765');
      expect(phone.isComplete, isFalse);
    });

    test('an empty number is neither valid nor complete', () {
      final phone = PhoneNumber.parse('');
      expect(phone.isValid, isFalse);
      expect(phone.isComplete, isFalse);
    });

    test('matches the E.164 shape the API enforces', () {
      // The backend validates ^\+?[1-9]\d{7,14}$ after stripping punctuation.
      final backendPattern = RegExp(r'^\+?[1-9]\d{7,14}$');
      expect(
        backendPattern.hasMatch(PhoneNumber.parse('9876543210').e164),
        isTrue,
      );
    });
  });

  group('display', () {
    test('groups Indian numbers for readability', () {
      expect(PhoneNumber.parse('9876543210').formattedNational, '98765 43210');
    });

    test('masks all but the last four digits', () {
      expect(PhoneNumber.parse('9876543210').masked, '+91 ••••••3210');
    });
  });

  test('value equality', () {
    expect(PhoneNumber.parse('9876543210'), PhoneNumber.parse('98765 43210'));
    expect(
      PhoneNumber.parse('9876543210'),
      isNot(PhoneNumber.parse('9876543211')),
    );
  });
}
