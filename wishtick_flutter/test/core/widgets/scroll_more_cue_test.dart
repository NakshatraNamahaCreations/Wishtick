import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/widgets/scroll_more_cue.dart';

void main() {
  const surface = Size(400, 600);

  /// [rows] tall enough to overflow, or short enough to fit.
  Future<ScrollController> pump(
    WidgetTester tester, {
    required int rows,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ScrollMoreCue(
            controller: controller,
            child: ListView(
              controller: controller,
              children: [
                for (var i = 0; i < rows; i++)
                  SizedBox(height: 100, child: Text('row $i')),
              ],
            ),
          ),
          bottomNavigationBar: const SizedBox(height: 80),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  // The fade is the first AnimatedOpacity in the stack, the pill the last.
  Finder fade() => find.byType(AnimatedOpacity).first;
  Finder pill() => find.byType(AnimatedOpacity).last;
  double opacityOf(WidgetTester tester, Finder finder) =>
      tester.widget<AnimatedOpacity>(finder).opacity;

  testWidgets('cues both the fade and the pill when there is more below', (
    tester,
  ) async {
    await pump(tester, rows: 20);

    expect(find.text('More'), findsOneWidget);
    expect(opacityOf(tester, fade()), 1);
  });

  /// The loud cue earns its place once. The fade stays, because there is still
  /// more below.
  testWidgets('the pill goes after the first scroll, the fade does not', (
    tester,
  ) async {
    final controller = await pump(tester, rows: 20);

    controller.jumpTo(200);
    await tester.pumpAndSettle();

    expect(opacityOf(tester, pill()), 0);
    expect(opacityOf(tester, fade()), 1);
  });

  testWidgets('neither cue when the content already fits', (tester) async {
    await pump(tester, rows: 2);

    expect(opacityOf(tester, fade()), 0);
    expect(opacityOf(tester, pill()), 0);
  });

  /// A gradient hanging over the last row would promise content that is not
  /// there.
  testWidgets('the fade lifts at the bottom of the list', (tester) async {
    final controller = await pump(tester, rows: 20);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(opacityOf(tester, fade()), 0);
  });

  testWidgets('tapping the pill scrolls the page down', (tester) async {
    final controller = await pump(tester, rows: 20);
    expect(controller.offset, 0);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
    // Gone, because tapping it counts as scrolling.
    expect(opacityOf(tester, pill()), 0);
  });
}
