import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_dimens.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/home/presentation/widgets/home_cards.dart';

import '../../../helpers/group_gift_fakes.dart';

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

  group('GroupGiftCard', () {
    // The rail's real geometry: a 361-wide card on the 393-px frame, at the
    // artwork's own 552x450 ratio. The copy's share of it is what the layout
    // assertions below are measured against.
    const cardWidth = 361.0;
    const cardHeight = 296.0;

    Future<void> pumpCard(
      WidgetTester tester, {
      String? message,
      DateTime? deadline,
      VoidCallback? onChipIn,
    }) async {
      tester.view
        ..physicalSize = const Size(393, 800)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: GroupGiftCard(
              gift: buildGroupGift(
                targetAmountMinor: 1600000,
                collectedAmountMinor: 1440000,
                message: message,
                deadline: deadline,
              ),
              title: "Ananya's 24th",
              onChipIn: onChipIn ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('is drawn on the celebration artwork', (tester) async {
      await pumpCard(tester);

      expect(
        assetNameOf(tester),
        "assets/images/Home_page_banners/Ananya's 24th.png",
      );
    });

    testWidgets('names the gift in caps over the goal so far', (tester) async {
      await pumpCard(tester);

      expect(find.text("ANANYA'S 24TH"), findsOneWidget);
      expect(find.text('Group Gift'), findsOneWidget);
      expect(find.text('₹14,400 of ₹16,000'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.9, 0.001),
      );
    });

    testWidgets("carries the host's note under the title", (tester) async {
      await pumpCard(
        tester,
        message: 'Join us as we make this birthday truly unforgettable.',
      );

      expect(
        find.text('Join us as we make this birthday truly unforgettable.'),
        findsOneWidget,
      );
    });

    // A blank line of type where the note would be is worse than no note: it
    // pushes the goal up the card for no reason the reader can see.
    testWidgets('leaves the note out when the host wrote none', (tester) async {
      await pumpCard(tester, message: '   ');

      // Title, "Group Gift", the amount and "Chip in" — nothing else.
      expect(find.byType(Text), findsNWidgets(4));
    });

    testWidgets('counts down to the deadline when there is one', (
      tester,
    ) async {
      expect(find.byType(WhenPill), findsNothing);

      await pumpCard(
        tester,
        deadline: DateTime.now().add(const Duration(days: 3)),
      );

      expect(find.text('In 3 days'), findsOneWidget);
    });

    // The cake and the balloons own the right-hand two fifths of the artwork.
    // Copy that runs into them is copy nobody can read.
    testWidgets('keeps the copy clear of the artwork', (tester) async {
      await pumpCard(tester);

      // The bar stretches the full width the copy is allowed.
      const inner = cardWidth - AppSpacing.lg * 2;
      expect(
        tester.getSize(find.byType(LinearProgressIndicator)).width,
        closeTo(inner * 3 / 5, 1),
      );
    });

    testWidgets('chips in', (tester) async {
      var chipIns = 0;
      await pumpCard(tester, onChipIn: () => chipIns++);

      await tester.tap(find.text('Chip in'));
      await tester.pump();

      expect(chipIns, 1);
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
