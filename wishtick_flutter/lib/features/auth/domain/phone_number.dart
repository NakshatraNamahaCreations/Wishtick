import 'package:flutter/foundation.dart';

/// A phone number in the shape the backend accepts.
///
/// The API validates against `^\+?[1-9]\d{7,14}$` after stripping spaces,
/// brackets and dashes, so this type normalises to exactly that before anything
/// is sent. Wishtick's first market is India, hence the `+91` default dial code.
@immutable
class PhoneNumber {
  const PhoneNumber._(this.dialCode, this.nationalNumber);

  final String dialCode;
  final String nationalNumber;

  static const defaultDialCode = '+91';

  /// Digits expected after the dial code, per country. Used for the "when is
  /// the field complete" check that enables the Continue button.
  static const _nationalLength = <String, int>{'+91': 10};

  static int nationalLengthFor(String dialCode) =>
      _nationalLength[dialCode] ?? 10;

  /// Everything the API cares about: `+919876543210`.
  String get e164 => '$dialCode$nationalNumber';

  /// Grouped for display — `98765 43210` for India.
  String get formattedNational {
    if (dialCode == '+91' && nationalNumber.length > 5) {
      return '${nationalNumber.substring(0, 5)} '
          '${nationalNumber.substring(5)}';
    }
    return nationalNumber;
  }

  String get masked {
    if (nationalNumber.length < 4) return e164;
    final tail = nationalNumber.substring(nationalNumber.length - 4);
    return '$dialCode ${'•' * (nationalNumber.length - 4)}$tail';
  }

  bool get isComplete =>
      nationalNumber.length == nationalLengthFor(dialCode) && isValid;

  /// Matches the backend's own regex against the composed E.164 value.
  bool get isValid => _e164Pattern.hasMatch(e164);

  static final _e164Pattern = RegExp(r'^\+?[1-9]\d{7,14}$');

  /// Builds from raw user input. Strips the punctuation the backend strips,
  /// and tolerates the user typing their own country code or a leading zero.
  factory PhoneNumber.parse(String input, {String dialCode = defaultDialCode}) {
    var digits = input.replaceAll(RegExp(r'[\s()\-]'), '');

    if (digits.startsWith('+')) {
      // The user typed a full international number — trust it over the picker.
      final code = _dialCodeOf(digits);
      if (code != null) {
        return PhoneNumber._(code, digits.substring(code.length));
      }
      digits = digits.substring(1);
    }

    digits = digits.replaceAll(RegExp(r'\D'), '');

    // A leading zero is national trunk notation and is never part of E.164.
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    final bare = dialCode.replaceAll('+', '');
    if (digits.length > nationalLengthFor(dialCode) &&
        digits.startsWith(bare)) {
      digits = digits.substring(bare.length);
    }

    final max = nationalLengthFor(dialCode);
    if (digits.length > max) digits = digits.substring(0, max);

    return PhoneNumber._(dialCode, digits);
  }

  static String? _dialCodeOf(String e164) {
    for (final code in _nationalLength.keys) {
      if (e164.startsWith(code)) return code;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is PhoneNumber &&
      other.dialCode == dialCode &&
      other.nationalNumber == nationalNumber;

  @override
  int get hashCode => Object.hash(dialCode, nationalNumber);

  @override
  String toString() => e164;
}
