import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Turns raw digit entry into `dd/mm/yyyy` as the user types — inserting the
/// slashes for them and capping input at 8 digits — while keeping the caret
/// where the digit count says it should be, not just parked at the end.
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsBeforeCaret = newValue.text
        .substring(0, newValue.selection.end.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;

    final buffer = StringBuffer();
    var caret = limited.length;
    for (var i = 0; i < limited.length; i++) {
      buffer.write(limited[i]);
      if (i + 1 == digitsBeforeCaret) caret = buffer.length;
      if (i == 1 || i == 3) buffer.write('/');
    }
    if (digitsBeforeCaret == 0) caret = 0;

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}

/// Parses a complete `dd/mm/yyyy` box into a real calendar date, or `null`
/// if the day doesn't exist in that month (`DateTime` itself would happily
/// roll "31/02" over into March, which reads as silently wrong here).
DateTime? parseTypedDate(String formatted) {
  if (formatted.length != 10) return null;
  final day = int.tryParse(formatted.substring(0, 2));
  final month = int.tryParse(formatted.substring(3, 5));
  final year = int.tryParse(formatted.substring(6, 10));
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12) return null;
  // Day 0 of next month == the last real day of this one.
  final daysInMonth = DateTime(year, month + 1, 0).day;
  if (day < 1 || day > daysInMonth) return null;
  return DateTime(year, month, day);
}

/// A `dd/mm/yyyy` box the user can either type into directly or fill via a
/// calendar picker — never both from the same tap.
///
/// Tapping the text opens the keyboard, never the picker; tapping the
/// calendar icon (its own separate tap target) opens the picker, never the
/// keyboard. A box that opens the picker on any tap — the original design
/// for every date field in this app — left no way to type a date by hand.
///
/// Below 8 typed digits [onChanged] fires with `null` — an in-progress edit
/// must not leave a stale committed date behind a box that no longer
/// displays it. At 8 digits the box validates the *real* calendar date (not
/// just well-formed digits) against [firstDate]/[lastDate], reports either
/// the parsed [DateTime] or `null` via [onChanged], and reports a message
/// via [onValidationError] describing why an invalid/out-of-range date was
/// rejected (or `null` once the box is valid or still mid-edit).
///
/// Uncontrolled after the first build, like [TextFormField.initialValue] —
/// to reset the box's own typed text from outside (e.g. after a successful
/// save clears the underlying value), give it a new [Key] rather than
/// expecting [initialDate] to resync a live instance.
class DateEntryField extends StatefulWidget {
  const DateEntryField({
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    required this.calendarIcon,
    this.initialDate,
    this.pickerInitialDate,
    this.pickerHelpText,
    this.decoration = const InputDecoration(),
    this.style,
    this.onValidationError,
    this.tooEarlyText = 'That date is too early',
    this.tooLateText = 'That date is too far ahead',
    super.key,
  });

  final DateTime? initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  /// Where the calendar picker opens when nothing has been typed yet.
  /// Falls back to [firstDate] if omitted.
  final DateTime? pickerInitialDate;
  final String? pickerHelpText;

  /// Fires with the parsed date once the box holds a complete, valid one —
  /// and with `null` the instant it stops (mid-edit, cleared, or invalid).
  final ValueChanged<DateTime?> onChanged;

  final ValueChanged<String?>? onValidationError;

  /// hintText defaults to `dd/mm/yyyy` if left unset. A `suffixIcon` set
  /// here is overwritten — see [calendarIcon].
  final InputDecoration decoration;
  final TextStyle? style;

  /// Wrapped in its own tap region and used as the field's `suffixIcon` —
  /// build it already coloured/sized for the screen it's on.
  final Widget calendarIcon;

  final String tooEarlyText;
  final String tooLateText;

  @override
  State<DateEntryField> createState() => _DateEntryFieldState();
}

class _DateEntryFieldState extends State<DateEntryField> {
  late final TextEditingController _controller;
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.initialDate));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  static String _format(DateTime? date) {
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _pickDate() async {
    // Opening the picker shouldn't leave the keyboard half up behind it.
    _focus.unfocus();

    final picked = await showDatePicker(
      context: context,
      initialDate:
          parseTypedDate(_controller.text) ??
          widget.pickerInitialDate ??
          widget.firstDate,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      helpText: widget.pickerHelpText,
    );
    if (picked == null || !mounted) return;
    _controller.text = _format(picked);
    _setError(null);
    widget.onChanged(picked);
  }

  void _setError(String? error) {
    if (_error == error) return;
    setState(() => _error = error);
    widget.onValidationError?.call(error);
  }

  /// Runs after every keystroke — [DateInputFormatter] has already turned
  /// the raw digits into `dd/mm/yyyy` by the time this sees them.
  void _onChanged(String formatted) {
    final digitCount = formatted.replaceAll('/', '').length;
    if (digitCount < 8) {
      _setError(null);
      widget.onChanged(null);
      return;
    }

    final parsed = parseTypedDate(formatted);
    final error = switch (parsed) {
      null => "That date doesn't exist — check the day and month",
      _ when parsed.isBefore(widget.firstDate) => widget.tooEarlyText,
      _ when parsed.isAfter(widget.lastDate) => widget.tooLateText,
      _ => null,
    };

    _setError(error);
    widget.onChanged(error == null ? parsed : null);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      onChanged: _onChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [DateInputFormatter()],
      style: widget.style,
      decoration: widget.decoration.copyWith(
        hintText: widget.decoration.hintText ?? 'dd/mm/yyyy',
        suffixIcon: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _pickDate,
          child: widget.calendarIcon,
        ),
      ),
    );
  }
}
