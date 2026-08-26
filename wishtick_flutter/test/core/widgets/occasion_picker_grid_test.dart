import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/widgets/occasion_picker_grid.dart';
import 'package:wishtick_flutter/core/widgets/selection_caret.dart';
import 'package:wishtick_flutter/features/events/presentation/create_event_controller.dart';
import 'package:wishtick_flutter/features/memories/presentation/create_memory_controller.dart';
import 'package:wishtick_flutter/features/memories/presentation/widgets/occasion_grid.dart';

/// The picker shared by event creation (`257:733`) and memory creation
/// (`4104:1539`).
///
/// These two grids were copies, and the copies drifted: the event screen was
/// given the real photographs while the memory screen quietly kept its
/// stand-in Material glyphs. The assertions here are the ones that would have
/// caught that.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view
      ..physicalSize = const Size(393, 1000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pump();
  }

  group('the artwork table', () {
    test('covers every occasion both screens offer', () {
      // A miss falls back to a neutral glyph rather than throwing, so a
      // renamed label would silently put one grey icon among seven photos.
      for (final o in kEventOccasions) {
        expect(
          kOccasionArtwork[o.label],
          isNotNull,
          reason: 'no artwork for the event occasion "${o.label}"',
        );
      }
      for (final o in kMemoryOccasions) {
        expect(
          kOccasionArtwork[o.label],
          isNotNull,
          reason: 'no artwork for the memory occasion "${o.label}"',
        );
      }
    });

    test('the two screens offer the same occasions in the same order, which '
        'is what makes one table by label safe', () {
      expect(
        [for (final o in kMemoryOccasions) o.label],
        [for (final o in kEventOccasions) o.label],
      );
      // Their *keys* differ, which is exactly why the table is not keyed on
      // them: `house_warming` against `housewarming`, and so on.
      expect([
        for (final o in kMemoryOccasions) o.key,
      ], isNot([for (final o in kEventOccasions) o.key]));
    });
  });

  testWidgets('the memory grid draws the photographs, not the glyphs it '
      'used to', (tester) async {
    await pump(tester, OccasionGrid(selectedKey: 'birthday', onSelect: (_) {}));

    for (final o in kMemoryOccasions) {
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              (w.image as AssetImage).assetName == kOccasionArtwork[o.label],
        ),
        findsOneWidget,
        reason: '${o.label} should draw its illustration',
      );
    }
    // The specific stand-ins this grid shipped with.
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

  testWidgets('the memory grid marks its selection with the same caret', (
    tester,
  ) async {
    await pump(
      tester,
      OccasionGrid(selectedKey: 'housewarming', onSelect: (_) {}),
    );

    expect(find.byType(SelectionCaret), findsOneWidget);
    // On the tile it names, not merely somewhere on the grid — the memory
    // screen's keys differ from the event screen's, so a key mismatch would
    // otherwise park the caret on the fallback first tile.
    final caret = tester.getRect(find.byType(SelectionCaret));
    final tile = tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName ==
                kOccasionArtwork['House Warming'],
      ),
    );
    expect(caret.center.dx, closeTo(tile.center.dx, 1));
  });

  testWidgets('selecting reports the key the caller gave, not the label', (
    tester,
  ) async {
    final picked = <String>[];
    await pump(
      tester,
      OccasionGrid(selectedKey: 'birthday', onSelect: picked.add),
    );

    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName == kOccasionArtwork['Rakhi'],
      ),
    );
    await tester.pump();

    expect(picked, ['rakhi']);
  });
}
