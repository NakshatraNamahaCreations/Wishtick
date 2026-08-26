import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_dimens.dart';
import 'package:wishtick_flutter/core/theme/app_palette.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/widgets/curved_bottom_clipper.dart';
import 'package:wishtick_flutter/core/widgets/selection_caret.dart';
import 'package:wishtick_flutter/features/events/presentation/create_event_screen.dart';

/// "What are you celebrating?" (`257:733`) — the occasion picker.
///
/// The grid used stand-in Material glyphs while the illustrations were thought
/// to be unexported; they are the real `Celebrations_images` photos now.
void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CreateEventScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  Finder assetNamed(String path) => find.byWidgetPredicate(
    (w) => w is Image && (w.image as AssetImage).assetName == path,
  );

  /// Label → artwork, in the frame's reading order.
  const expected = {
    'Birthday': 'assets/images/Celebrations_images/Birthday.png',
    'Anniversary': 'assets/images/Celebrations_images/Anniversary.png',
    'Wedding': 'assets/images/Celebrations_images/Wedding.png',
    'House Warming': 'assets/images/Celebrations_images/House_Warming.png',
    'Mom to Be': 'assets/images/Celebrations_images/Mom_to_Be.png',
    // Deliberately crossed: the frame's "Custom Events" is the bouquet and its
    // "Best Wishes" is the gift box, while the filenames follow Home's grid.
    'Custom Events': 'assets/images/Celebrations_images/Best_Wishes.png',
    'Rakhi': 'assets/images/Celebrations_images/Rakhi.png',
    'Best Wishes': 'assets/images/Celebrations_images/Just_Because.png',
  };

  testWidgets('every occasion is its illustration, not a stand-in glyph', (
    tester,
  ) async {
    await pump(tester);

    for (final entry in expected.entries) {
      expect(
        assetNamed(entry.value),
        findsOneWidget,
        reason: '${entry.key} should draw ${entry.value}',
      );
    }
    expect(find.byType(Image), findsNWidgets(expected.length));
  });

  testWidgets('the crossed pair is not two of the same picture', (
    tester,
  ) async {
    await pump(tester);

    // The one mistake this mapping invites: pointing both at one file.
    expect(
      assetNamed('assets/images/Celebrations_images/Best_Wishes.png'),
      findsOneWidget,
    );
    expect(
      assetNamed('assets/images/Celebrations_images/Just_Because.png'),
      findsOneWidget,
    );
  });

  testWidgets('none of the old placeholder glyphs survive', (tester) async {
    await pump(tester);

    for (final icon in const [
      Icons.cake_outlined,
      Icons.favorite_border,
      Icons.church_outlined,
      Icons.home_outlined,
      Icons.child_friendly_outlined,
      Icons.volunteer_activism_outlined,
      Icons.card_giftcard,
      Icons.celebration_outlined,
    ]) {
      expect(find.byIcon(icon), findsNothing);
    }
  });

  testWidgets('the masthead bends the way 257:733 draws it, not the way the '
      'Sprint 11 headers do', (tester) async {
    await pump(tester);

    final clippers = tester
        .widgetList<ClipPath>(find.byType(ClipPath))
        .map((c) => c.clipper)
        .whereType<CurvedBottomClipper>()
        .toList();

    expect(clippers, isNotEmpty, reason: 'the header should be clipped');
    // The clipper's own test proves each shape; this proves the screen asks
    // for the right one. Without it, flipping this back to a sag is silent.
    expect(clippers.single.edge, CurvedBottomEdge.rise);
    expect(clippers.single.dip, CurvedBottomClipper.eventRise);
  });

  testWidgets('the masthead is the three-stop wash 257:733 specifies, not a '
      'flat plum', (tester) async {
    await pump(tester);

    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byWidgetPredicate(
              (w) => w is ClipPath && w.clipper is CurvedBottomClipper,
            ),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = box.decoration! as BoxDecoration;

    // A `color` here would paint over the gradient, so the flat fill has to be
    // gone rather than merely overridden.
    expect(decoration.color, isNull);
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, const [
      AppPalette.plumShadow,
      AppPalette.plumRich,
      AppPalette.plumMuted,
    ]);
    // Straight down: sideways or inverted would put the near-black at the
    // curve instead of under the status bar.
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
  });

  testWidgets("the header's rounded top corners show the dimmed page, not "
      'the page colour', (tester) async {
    await pump(tester);

    // By its clipper, not by type: the occasion cards clip themselves too.
    final header = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is CurvedBottomClipper,
      ),
    );
    // Whatever fills the page colour behind the header must stop short of its
    // top corners; covering them paints two opaque notches where the dimmed
    // page belongs.
    for (final box in tester.widgetList<ColoredBox>(find.byType(ColoredBox))) {
      // Transparent fills cannot paint a notch — the Scaffold's own is one,
      // and it spans the whole screen.
      if (box.color.a == 0) continue;
      final rect = tester.getRect(find.byWidget(box));
      if (rect.overlaps(header)) {
        expect(
          rect.top,
          greaterThanOrEqualTo(header.top + AppRadius.sheet),
          reason: "page colour reaches into the header's rounded corners",
        );
      }
    }
  });

  testWidgets('only the selected occasion wears the caret, and it hangs '
      'below the tile rather than sitting inside it', (tester) async {
    await pump(tester);

    // Exactly one: a caret per tile, or none at all, both look plausible in a
    // diff and neither matches the frame.
    expect(find.byType(SelectionCaret), findsOneWidget);

    final caret = tester.getRect(find.byType(SelectionCaret));
    final tile = tester.getRect(
      find
          .ancestor(
            of: assetNamed(expected['Birthday']!),
            matching: find.byType(Stack),
          )
          .first,
    );

    // The caret belongs to the selected tile...
    expect(tile.overlaps(caret), isTrue);
    // ...and pokes out of its foot. Clipped or centred, it would not.
    expect(caret.bottom, greaterThan(tile.bottom));
    expect(caret.top, lessThan(tile.bottom));
  });

  testWidgets('picking a different occasion moves the caret onto it', (
    tester,
  ) async {
    await pump(tester);

    // The tile, not the label beneath it: the label sits outside the InkWell,
    // so tapping it does nothing.
    await tester.tap(assetNamed(expected['Wedding']!));
    await tester.pump();

    expect(find.byType(SelectionCaret), findsOneWidget);
    final caret = tester.getRect(find.byType(SelectionCaret));
    final wedding = tester.getRect(assetNamed(expected['Wedding']!));
    final birthday = tester.getRect(assetNamed(expected['Birthday']!));

    // Horizontal centres, because the two tiles share a row: the caret is
    // under Wedding's column now, not still under Birthday's.
    expect(caret.center.dx, closeTo(wedding.center.dx, 1));
    expect(caret.center.dx, isNot(closeTo(birthday.center.dx, 1)));
  });

  testWidgets('tapping an occasion selects it', (tester) async {
    await pump(tester);

    /// The tiles currently drawing the heavier selected border.
    List<Rect> selected() => tester
        .widgetList<Container>(find.byType(Container))
        .where((c) {
          final border = (c.decoration as BoxDecoration?)?.border;
          return border is Border && border.top.width > 1;
        })
        .map((c) => tester.getRect(find.byWidget(c)))
        .toList();

    // Birthday arrives selected, so "some tile has a heavy border" is true
    // before the tap and proves nothing — the assertion has to be that the
    // border *moved*.
    final before = selected();
    expect(before, hasLength(1));

    await tester.tap(assetNamed(expected['Anniversary']!));
    await tester.pump();

    final after = selected();
    expect(after, hasLength(1));
    expect(after.single, isNot(before.single));
    expect(
      after.single.center.dx,
      closeTo(
        tester.getRect(assetNamed(expected['Anniversary']!)).center.dx,
        1,
      ),
    );
  });
}
