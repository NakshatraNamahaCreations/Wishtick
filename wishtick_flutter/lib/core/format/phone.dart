/// Turning what is in somebody's address book into something the server can
/// match against an account.
///
/// A contact is free text. The same person is stored as `98765 43210`,
/// `+91 98765-43210`, `098765 43210` and `0091 9876543210`, and an invite
/// addressed to any of those has to find the account that signed up as
/// `+919876543210` — otherwise the guest taps their link and is told they are
/// not on the list.
library;

/// The country code assumed for a number written without one.
///
/// India, because that is where the app's prices, timezone and sign-up flow
/// already point. A host whose own number says otherwise overrides it — see
/// [dialCodeOf] — so this is only the answer when nothing better is known.
const kDefaultDialCode = '+91';

/// Every calling code the app can infer from a host's own number.
///
/// Deliberately short. A full table is a package in its own right, and a wrong
/// guess is worse than no guess: it produces an invite nobody can ever claim.
/// Anything not listed falls back to [kDefaultDialCode], and a contact stored
/// with its own `+` is never guessed at in the first place.
const _knownDialCodes = <String>[
  '+91', // India
  '+1', // US / Canada
  '+44', // UK
  '+61', // Australia
  '+65', // Singapore
  '+971', // UAE
  '+966', // Saudi Arabia
  '+60', // Malaysia
  '+94', // Sri Lanka
  '+977', // Nepal
];

/// The calling code [e164] begins with, or null when it is not one we know.
///
/// Longest first: `+977` and `+97` would both match a Nepalese number, and the
/// shorter one would leave a digit of the subscriber number in the prefix.
String? dialCodeOf(String? e164) {
  if (e164 == null) return null;
  final trimmed = e164.trim();
  if (!trimmed.startsWith('+')) return null;
  final sorted = [..._knownDialCodes]
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final code in sorted) {
    if (trimmed.startsWith(code)) return code;
  }
  return null;
}

/// [raw] as E.164 (`+919876543210`), or null when it cannot be one.
///
/// [defaultDialCode] is what a bare local number is assumed to belong to —
/// pass the host's own, since their address book is overwhelmingly people in
/// the same country.
///
/// Null rather than a guess for anything too short to be a phone number: an
/// address book holds extensions, dates and note fields, and inviting `1234`
/// creates a row nobody will ever claim.
String? normalizeToE164(
  String raw, {
  String defaultDialCode = kDefaultDialCode,
}) {
  // Everything a person might use to make a number readable.
  var s = raw.replaceAll(RegExp(r'[\s()\-. ]'), '');
  if (s.isEmpty) return null;

  // `00` is the other way of writing `+` — common in numbers saved abroad.
  if (s.startsWith('00')) s = '+${s.substring(2)}';

  if (s.startsWith('+')) {
    final digits = s.substring(1);
    if (!_isDigits(digits) || digits.length < 8 || digits.length > 15) {
      return null;
    }
    return '+$digits';
  }

  if (!_isDigits(s)) return null;

  // A national trunk prefix: `098765…` dialled inside India. It is not part of
  // the number once a country code is on the front.
  if (s.startsWith('0')) s = s.replaceFirst(RegExp('^0+'), '');
  if (s.length < 6 || s.length > 15) return null;

  // Already carries its country code without the `+` — how a number pasted
  // out of a chat often looks.
  final code = defaultDialCode.replaceAll('+', '');
  if (s.length > 10 && s.startsWith(code)) return '+$s';

  return '$defaultDialCode$s';
}

bool _isDigits(String s) => s.isNotEmpty && RegExp(r'^\d+$').hasMatch(s);

/// A number as a person reads it back: `+91 98765 43210`.
///
/// Only for display. Everything sent to the server is plain E.164.
String formatE164ForDisplay(String e164) {
  final code = dialCodeOf(e164);
  if (code == null) return e164;
  final rest = e164.substring(code.length);
  if (rest.length < 6) return e164;
  final half = (rest.length / 2).ceil();
  return '$code ${rest.substring(0, half)} ${rest.substring(half)}';
}
