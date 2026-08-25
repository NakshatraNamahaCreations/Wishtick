import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/discover/presentation/widgets/product_card_skeleton.dart';

/// The placeholder that stands in while a search is in flight.
///
/// A product search is a live scrape upstream and can take seconds, so this is
/// on screen long enough to matter.
void main() {
  Future<void> pump(WidgetTester tester, {bool reduceMotion = false}) async {
    tester.view
      ..physicalSize = const Size(200, 400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: const Scaffold(body: ProductCardSkeleton()),
        ),
      ),
    );
  }

  testWidgets('draws placeholder blocks, never a spinner', (tester) async {
    await pump(tester);

    expect(find.byType(ProductCardSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Nothing here is real content, so nothing should read as text.
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('the sheen settles under reduced motion, so it cannot spin '
      'forever', (tester) async {
    await pump(tester, reduceMotion: true);

    // A repeating animation never lets the tree settle; this returning at all
    // is the assertion.
    await tester.pumpAndSettle();

    expect(find.byType(ProductCardSkeleton), findsOneWidget);
  });

  testWidgets('animates while motion is allowed', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 100));

    // The controller is repeating, so frames keep being scheduled.
    expect(tester.binding.hasScheduledFrame, isTrue);
  });
}
