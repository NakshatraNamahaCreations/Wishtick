import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/format/phone.dart';

/// Contacts are free text, and an invite that does not normalise to the same
/// string the account signed up with is an invite nobody can ever claim.
void main() {
  group('normalising a contact', () {
    test('the same person, written every way an address book writes them', () {
      // All of these are one number, and all must reach one account.
      for (final raw in [
        '+919876543210',
        '+91 98765 43210',
        '+91-98765-43210',
        '+91 (98765) 43210',
        '0091 9876543210',
        '09876543210',
        '9876543210',
        '98765 43210',
        '919876543210',
      ]) {
        expect(normalizeToE164(raw), '+919876543210', reason: raw);
      }
    });

    test('a bare local number takes the host’s own country, not India’s', () {
      // A host in the UK has a UK address book. Assuming +91 for them would
      // invite numbers that can never be claimed.
      expect(
        normalizeToE164('07700900123', defaultDialCode: '+44'),
        '+447700900123',
      );
      expect(
        normalizeToE164('4155550123', defaultDialCode: '+1'),
        '+14155550123',
      );
    });

    test('a number carrying its own + is never re-guessed', () {
      // The host's country is irrelevant once the contact says which country
      // it is in.
      expect(
        normalizeToE164('+14155550123', defaultDialCode: '+91'),
        '+14155550123',
      );
    });

    test('what is not a phone number is refused rather than guessed at', () {
      // An address book holds extensions, dates, and notes. Inviting one of
      // those makes a row nobody will ever claim.
      for (final junk in [
        '',
        '   ',
        '1234',
        '12',
        'not a number',
        '+12',
        '#101',
      ]) {
        expect(normalizeToE164(junk), isNull, reason: junk);
      }
    });

    test('an absurdly long string is refused', () {
      // E.164 tops out at 15 digits.
      expect(normalizeToE164('+1234567890123456'), isNull);
    });
  });

  group('reading a host’s own country off their number', () {
    test('finds the code, longest first', () {
      expect(dialCodeOf('+919876543210'), '+91');
      expect(dialCodeOf('+14155550123'), '+1');
      // +977 and +97 would both match; the longer one is the real country.
      expect(dialCodeOf('+9779812345678'), '+977');
    });

    test('null for a number with no code, or a country we do not list', () {
      expect(dialCodeOf(null), isNull);
      expect(dialCodeOf('9876543210'), isNull);
      expect(dialCodeOf('+99912345678'), isNull);
    });
  });

  test('a number is shown grouped, and sent plain', () {
    expect(formatE164ForDisplay('+919876543210'), '+91 98765 43210');
    // Nothing it cannot parse is mangled.
    expect(formatE164ForDisplay('+99912345'), '+99912345');
  });
}
