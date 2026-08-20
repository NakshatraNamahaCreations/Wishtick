import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/widgets/pick_tile.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String? image,
    IconData? icon,
    bool selected = false,
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: PickTile(
          label: 'Birthday',
          image: image,
          icon: icon,
          selected: selected,
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );

  testWidgets('renders the given photo, not an icon, when image is set', (
    tester,
  ) async {
    await pump(tester, image: 'assets/images/Celebrations_images/Birthday.png');

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName ==
                'assets/images/Celebrations_images/Birthday.png',
      ),
      findsOneWidget,
    );
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('renders the given icon, not a photo, when icon is set', (
    tester,
  ) async {
    await pump(tester, icon: Icons.favorite_outline);

    expect(find.byIcon(Icons.favorite_outline), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('tapping calls onTap', (tester) async {
    var tapped = false;
    await pump(
      tester,
      image: 'assets/images/Celebrations_images/Birthday.png',
      onTap: () => tapped = true,
    );

    await tester.tap(find.text('Birthday'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
