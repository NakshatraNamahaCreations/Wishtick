import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/widgets/dismiss_keyboard_on_tap.dart';

void main() {
  Future<({FocusNode fieldFocus, ScrollController scrollController})>
  pumpScreen(WidgetTester tester) async {
    final fieldFocus = FocusNode();
    final scrollController = ScrollController();
    addTearDown(fieldFocus.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DismissKeyboardOnTap(
          child: Scaffold(
            body: Column(
              children: [
                TextField(key: const Key('field'), focusNode: fieldFocus),
                // Blank, non-scrollable space — isolates a plain outside tap
                // from anything a Scrollable's own gesture handling might
                // also react to. Coloured, not a bare SizedBox, so it is
                // actually part of the hit-test tree.
                const ColoredBox(
                  key: Key('blank'),
                  color: Colors.transparent,
                  child: SizedBox(height: 100, width: double.infinity),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: 40,
                    itemBuilder: (context, i) =>
                        SizedBox(height: 60, child: Text('Row $i')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return (fieldFocus: fieldFocus, scrollController: scrollController);
  }

  testWidgets('tapping blank space outside the field dismisses the keyboard', (
    tester,
  ) async {
    final s = await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(s.fieldFocus.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('blank')));
    await tester.pump();

    expect(
      s.fieldFocus.hasFocus,
      isFalse,
      reason: 'the outer tap should have unfocused the field',
    );
  });

  testWidgets('tapping the field itself still focuses it, not just opens '
      'and immediately closes the keyboard', (tester) async {
    final s = await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();

    expect(
      s.fieldFocus.hasFocus,
      isTrue,
      reason:
          'the wrapper sees this as a tap "outside" nothing — the field '
          'must win its own focus, not lose it to the same gesture',
    );
  });

  testWidgets('dragging a scroll view dismisses the keyboard', (tester) async {
    final s = await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(s.fieldFocus.hasFocus, isTrue);

    await tester.drag(find.text('Row 5'), const Offset(0, -200));
    await tester.pump();

    expect(s.fieldFocus.hasFocus, isFalse);
  });

  testWidgets('a programmatic scroll (no drag) leaves the keyboard alone', (
    tester,
  ) async {
    final s = await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(s.fieldFocus.hasFocus, isTrue);

    s.scrollController.jumpTo(300);
    await tester.pump();

    expect(
      s.fieldFocus.hasFocus,
      isTrue,
      reason:
          'jumpTo is not a drag — it must not fight the field it is '
          'probably scrolling to reveal',
    );
  });
}
