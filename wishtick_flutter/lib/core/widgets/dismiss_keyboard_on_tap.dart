import 'package:flutter/material.dart';

/// Dismisses the on-screen keyboard when the user taps anywhere outside the
/// focused field, or starts scrolling — wrapped once around the whole app
/// (see `app.dart`) rather than repeated per screen.
///
/// A tap that lands *on* a text field still focuses it as normal: this only
/// ever sees taps that no descendant already claimed.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({required this.child, super.key});

  final Widget child;

  static void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _unfocus,
      // Catches taps on otherwise-empty page background too, not just on
      // widgets that paint something.
      behavior: HitTestBehavior.opaque,
      child: NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          // `dragDetails` is null for a programmatic scroll (e.g. "jump to
          // the field with an error") — dismissing the keyboard then would
          // fight the very field that scroll is trying to reveal.
          if (notification.dragDetails != null) _unfocus();
          return false;
        },
        child: child,
      ),
    );
  }
}
