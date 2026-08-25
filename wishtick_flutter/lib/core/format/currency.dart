/// Formats minor-unit INR (paise) as a whole-rupee amount with Indian digit
/// grouping — `1099900` → `₹10,999`. The app only ever deals in INR today, so
/// this does not take a currency code.
String formatInrMinor(int? amountMinor) {
  if (amountMinor == null) return '—';
  final rupees = amountMinor ~/ 100;
  return '₹${_groupIndian(rupees.toString())}';
}

String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  final rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  for (var end = rest.length; end > 0; end -= 2) {
    final start = end - 2 < 0 ? 0 : end - 2;
    groups.insert(0, rest.substring(start, end));
  }
  return '${groups.join(',')},$last3';
}

/// Formats a plain count with the same Indian digit grouping as prices —
/// `13000` → `13,000`.
///
/// Shares [_groupIndian] with [formatInrMinor] on purpose: a review count
/// sitting beside a price in the same line should group the same way, and two
/// competing conventions in one screen is what makes numbers look wrong.
String formatCount(int value) => _groupIndian(value.toString());
