import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/home/presentation/widgets/occasion_grid.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    ValueChanged<OccasionTile>? onOccasionTap,
    VoidCallback? onCustomEventTap,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: OccasionGrid(
          onOccasionTap: onOccasionTap ?? (_) {},
          onCustomEventTap: onCustomEventTap ?? () {},
        ),
      ),
    ),
  );

  testWidgets('every real occasion is a photo, not an icon', (tester) async {
    await pump(tester);

    for (final occasion in kHomeOccasions) {
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image && (w.image as AssetImage).assetName == occasion.image,
        ),
        findsOneWidget,
        reason: '${occasion.label} should render ${occasion.image}',
      );
    }
    // Seven photos, none of the old glyphs standing in for them.
    expect(find.byType(Image), findsNWidgets(kHomeOccasions.length));
  });

  testWidgets('Custom Events stays the highlighted sparkle tile, not a '
      'photo', (tester) async {
    await pump(tester);

    expect(find.text('Custom Events'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
  });

  testWidgets('tapping a photo tile reports that occasion', (tester) async {
    OccasionTile? tapped;
    await pump(tester, onOccasionTap: (o) => tapped = o);

    await tester.tap(find.text('Birthday'));
    await tester.pump();

    expect(tapped?.key, 'birthday');
  });

  testWidgets('tapping Custom Events calls onCustomEventTap, not '
      'onOccasionTap', (tester) async {
    var customTapped = false;
    OccasionTile? occasionTapped;
    await pump(
      tester,
      onCustomEventTap: () => customTapped = true,
      onOccasionTap: (o) => occasionTapped = o,
    );

    await tester.tap(find.text('Custom Events'));
    await tester.pump();

    expect(customTapped, isTrue);
    expect(occasionTapped, isNull);
  });
}
