import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/home/presentation/widgets/home_cards.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );

  String? assetNameOf(WidgetTester tester) =>
      (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName;

  group('CelebrateMomentBanner', () {
    testWidgets('renders the flattened banner artwork', (tester) async {
      await pump(tester, const CelebrateMomentBanner());

      expect(
        assetNameOf(tester),
        'assets/images/Home_page_banners/Celebration spotlight banner.png',
      );
    });

    testWidgets('carries the banner copy as a semantic label, since it is '
        'baked into the image and invisible to a screen reader otherwise', (
      tester,
    ) async {
      await pump(tester, const CelebrateMomentBanner());

      expect(
        find.bySemanticsLabel(
          "Celebrate Every Moment. From life's biggest milestones to "
          'everyday joys.',
        ),
        findsOneWidget,
      );
    });
  });

  group('BirthdaysBanner', () {
    testWidgets('renders the flattened banner artwork', (tester) async {
      await pump(tester, const BirthdaysBanner());

      expect(
        assetNameOf(tester),
        'assets/images/Home_page_banners/Birthday spotlight banner.png',
      );
    });

    testWidgets('carries the banner copy as a semantic label', (tester) async {
      await pump(tester, const BirthdaysBanner());

      expect(
        find.bySemanticsLabel(
          'Birthdays Made Special. Never lose track of the gifts you love.',
        ),
        findsOneWidget,
      );
    });
  });
}
