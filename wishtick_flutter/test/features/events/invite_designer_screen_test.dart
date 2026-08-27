import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/events/domain/invite_design.dart';
import 'package:wishtick_flutter/features/events/presentation/invite_designer_screen.dart';
import 'package:wishtick_flutter/features/events/presentation/widgets/invite_canvas.dart';
import 'package:wishtick_flutter/features/events/presentation/widgets/invite_layer_handles.dart';
import 'package:wishtick_flutter/features/events/presentation/widgets/invite_style_bar.dart';

/// The invitation designer.
///
/// The contract the host is given is narrow and worth pinning: the background
/// is fixed by the template they chose, everything they add sits on top of it,
/// and the card that leaves is the one they were looking at.
void main() {
  Uint8List? exported;
  InviteDesign? returnedDesign;
  double? rasterisedAtRatio;

  setUpAll(() {
    // No network in a widget test, so a font fetch would hang forever and the
    // export — which waits on `pendingFonts` — would never fire its callback.
    // Off here, the picker still lists every face and the canvas draws them in
    // the fallback, which is exactly what a device shows before the download
    // lands.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    exported = null;
    returnedDesign = null;
    rasterisedAtRatio = null;
  });

  /// Stands in for the engine. Records the ratio the screen asked for, which is
  /// the part of the export that can go wrong silently.
  Future<Uint8List?> fakeRenderer(RenderRepaintBoundary boundary) async {
    rasterisedAtRatio = inviteExportPixelRatio(boundary.size.width);
    return Uint8List.fromList(const [1, 2, 3]);
  }

  Future<void> pump(
    WidgetTester tester, {
    InviteDesign design = const InviteDesign.empty('happy_birthday'),
    ThemeData? theme,
  }) async {
    tester.view
      ..physicalSize = const Size(393, 1100)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: InviteDesignerScreen(
            initial: design,
            renderer: fakeRenderer,
            onDone: (png, produced) async {
              exported = png;
              returnedDesign = produced;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps Done and lets the export finish.
  ///
  /// Fixed pumps rather than `pumpAndSettle`: Done shows a spinner while the
  /// card renders, and a `CircularProgressIndicator` never settles.
  Future<void> tapDone(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    // Past the export's font-wait timeout, so the bounded wait actually
    // elapses. Fixed pumps rather than `pumpAndSettle` because Done shows a
    // spinner, and a `CircularProgressIndicator` never settles.
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Adds a layer through the real flow — the button, then the dialog.
  Future<void> addText(WidgetTester tester, String text) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.widgetWithText(TextButton, 'Set text'));
    await tester.pumpAndSettle();
  }

  testWidgets('the chosen template fixes the background', (tester) async {
    await pump(tester);

    final canvas = tester.widget<InviteCanvas>(find.byType(InviteCanvas));
    expect(canvas.design.background, InviteBackgrounds.happyBirthday);

    // And there is no control that could change it. The template screen is
    // where the art is chosen; the designer only writes on it.
    expect(find.text('Background'), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsNothing);
  });

  testWidgets('adding text puts a styled layer on the card', (tester) async {
    await pump(tester);

    await addText(tester, 'Happy Birthday');

    final canvas = tester.widget<InviteCanvas>(find.byType(InviteCanvas));
    expect(canvas.design.layers.single.text, 'Happy Birthday');
    // Selected on arrival, so the style bar is already pointed at it — an
    // added layer that needs finding before it can be styled is a wasted tap.
    expect(find.byType(InviteStyleBar), findsOneWidget);
    expect(find.byType(InviteLayerHandles), findsOneWidget);
  });

  testWidgets(
    'clearing the text removes the layer instead of leaving a ghost',
    (tester) async {
      await pump(tester);
      await addText(tester, 'Temporary');

      // Re-open the dialog from the handle and empty it.
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.widgetWithText(TextButton, 'Set text'));
      await tester.pumpAndSettle();

      // An empty layer draws nothing but still holds handles, which would leave
      // the host dragging an invisible box around.
      final canvas = tester.widget<InviteCanvas>(find.byType(InviteCanvas));
      expect(canvas.design.layers, isEmpty);
      expect(find.byType(InviteStyleBar), findsNothing);
    },
  );

  testWidgets('tapping the card away from any layer puts the handles away', (
    tester,
  ) async {
    await pump(tester);
    await addText(tester, 'Hi');
    expect(find.byType(InviteStyleBar), findsOneWidget);

    // The top of the canvas — inside the card, clear of the centred layer.
    final canvas = tester.getRect(find.byType(InviteCanvas));
    await tester.tapAt(Offset(canvas.center.dx, canvas.top + 8));
    await tester.pumpAndSettle();

    // Deselecting is the only way to see the card as a guest will.
    expect(find.byType(InviteStyleBar), findsNothing);
    expect(find.byType(InviteLayerHandles), findsNothing);
  });

  testWidgets('the style bar edits the selected layer', (tester) async {
    await pump(tester);
    await addText(tester, 'Styled');

    TextLayer layerNow() => tester
        .widget<InviteCanvas>(find.byType(InviteCanvas))
        .design
        .layers
        .single;

    // Italic is off by default, so this proves the toggle wrote through.
    expect(layerNow().italic, isFalse);
    await tester.tap(find.byIcon(Icons.format_italic));
    await tester.pumpAndSettle();
    expect(layerNow().italic, isTrue);

    await tester.tap(find.byIcon(Icons.format_align_left));
    await tester.pumpAndSettle();
    expect(layerNow().align, LayerAlign.left);

    // The face list is a dropdown now — two dozen entries across four groups
    // do not fit a rail. Open it, then pick.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(InviteFonts.cormorant.label).last);
    await tester.pumpAndSettle();
    expect(layerNow().fontKey, InviteFonts.cormorant.key);
  });

  testWidgets('the selection box hugs the words, so short text sits centred', (
    tester,
  ) async {
    await pump(tester);
    // Short enough that a box sized to the layer's wrap width would be several
    // times wider than the glyphs, stranding the handles out near the balloons
    // with the text adrift in the middle of an empty outline.
    await addText(tester, 'Aug 27');

    final canvas = tester.getRect(find.byType(InviteCanvas));
    final layer = tester
        .widget<InviteCanvas>(find.byType(InviteCanvas))
        .design
        .layers
        .single;
    final wrapWidth = layer.widthFactor * canvas.width;
    final box = tester.getRect(find.byType(InviteLayerHandles));

    // The handles box carries [InviteLayerHandles.pad] of margin each side, so
    // compare the text box inside it. Strictly narrower than the wrap width is
    // the whole invariant — before this the box *was* the wrap width, whatever
    // the text.
    //
    // Not a tighter ratio: the test font draws every glyph a full em wide, so
    // short strings measure far wider here than in any real face.
    final textWidth = box.width - InviteLayerHandles.pad * 2;
    // A pixel of slack, not a bare `lessThan`: when the box *was* the wrap
    // width the two differed only in float noise, and the assertion passed on
    // it.
    expect(textWidth, lessThan(wrapWidth - 1));

    // And the words sit in the middle of it, horizontally and vertically.
    final glyphs = tester.getRect(find.text('Aug 27'));
    expect(glyphs.center.dx, closeTo(box.center.dx, 1.0));
    expect(glyphs.center.dy, closeTo(box.center.dy, 1.0));
  });

  testWidgets('long text still wraps at the layer width rather than hugging '
      'one endless line', (tester) async {
    await pump(tester);
    await addText(
      tester,
      'Come and celebrate with us on a warm evening in August',
    );

    final canvas = tester.getRect(find.byType(InviteCanvas));
    final layer = tester
        .widget<InviteCanvas>(find.byType(InviteCanvas))
        .design
        .layers
        .single;
    final wrapWidth = layer.widthFactor * canvas.width;
    final box = tester.getRect(find.byType(InviteLayerHandles));

    // Hugging must not mean "never wrap": the width factor is still the limit,
    // and text that ran off the card would be unreadable and unexportable.
    expect(
      box.width - InviteLayerHandles.pad * 2,
      lessThanOrEqualTo(wrapWidth + 1),
    );
    expect(box.height, greaterThan(canvas.height * 0.05));
  });

  testWidgets('dragging the corner widens the box so a word stops breaking', (
    tester,
  ) async {
    await pump(tester);
    // Long enough to overflow the default box and wrap. Widening the box —
    // not shrinking the letters — is what should unbreak it.
    await addText(tester, 'Celebrate!');

    TextLayer layerNow() => tester
        .widget<InviteCanvas>(find.byType(InviteCanvas))
        .design
        .layers
        .single;

    final beforeSize = layerNow().fontSize;
    final beforeWidth = layerNow().widthFactor;
    // Line count via height: one line is roughly the font size, two is double
    // it. RenderParagraph exposes no line count, and the height ratio is the
    // thing that actually changes on screen anyway.
    final canvasWidth = tester.getSize(find.byType(InviteCanvas)).width;
    final lineHeight = layerNow().fontSize * canvasWidth;
    final beforeHeight = tester.getSize(find.text('Celebrate!')).height;
    expect(
      beforeHeight,
      greaterThan(lineHeight * 1.5),
      reason: 'should start wrapped onto two lines',
    );

    // The bottom-right handle, dragged outwards.
    await tester.drag(find.byIcon(Icons.swap_horiz), const Offset(80, 0));
    await tester.pumpAndSettle();

    expect(layerNow().widthFactor, greaterThan(beforeWidth));
    // The letters must not have moved. This handle used to drive the font size,
    // which meant the only way to unbreak a word was to make it smaller.
    expect(layerNow().fontSize, beforeSize);
    expect(
      tester.getSize(find.text('Celebrate!')).height,
      lessThan(lineHeight * 1.5),
      reason: 'now on one line',
    );
  });

  testWidgets('the font picker offers every catalogued face, grouped', (
    tester,
  ) async {
    await pump(tester);
    await addText(tester, 'Fonts');

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    // The two bundled faces lead — they are the only ones guaranteed present
    // with no network.
    expect(find.text('IN THE APP'), findsOneWidget);
    expect(find.text('Display'.toUpperCase()), findsOneWidget);
    expect(find.text('Handwriting'.toUpperCase()), findsOneWidget);

    // A rail could not show this many; the count is the reason it is a
    // dropdown.
    expect(InviteFonts.all.length, greaterThan(20));
    expect(InviteFonts.all.first.isBundled, isTrue);
  });

  testWidgets('undo steps back through discrete edits', (tester) async {
    await pump(tester);
    await addText(tester, 'Undo me');

    await tester.tap(find.byIcon(Icons.format_bold));
    await tester.pumpAndSettle();
    final boldOff = tester
        .widget<InviteCanvas>(find.byType(InviteCanvas))
        .design
        .layers
        .single
        .bold;

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<InviteCanvas>(find.byType(InviteCanvas))
          .design
          .layers
          .single
          .bold,
      isNot(boldOff),
    );
  });

  testWidgets('Done rasterises the canvas and hands back the design that '
      'made it', (tester) async {
    await pump(tester);
    await addText(tester, 'Export me');

    await tapDone(tester);

    expect(exported, isNotNull);

    // The ratio is what turns the on-screen canvas into a 1080-wide card, and
    // it is derived from the live layout — so a change to the editor's padding
    // is exactly the thing that would quietly start exporting the wrong size.
    final canvasWidth = tester.getSize(find.byType(InviteCanvas)).width;
    expect(
      rasterisedAtRatio,
      closeTo(InviteDesign.exportWidth / canvasWidth, 1e-9),
    );
    expect(canvasWidth * rasterisedAtRatio!, closeTo(1080, 0.01));

    // The design travels with the PNG so the invitation can be reopened and
    // edited rather than re-made from scratch.
    expect(returnedDesign?.layers.single.text, 'Export me');
    expect(returnedDesign?.backgroundKey, 'happy_birthday');
  });

  testWidgets('selection chrome cannot reach the exported raster', (
    tester,
  ) async {
    await pump(tester);
    await addText(tester, 'Clean');
    expect(find.byType(InviteLayerHandles), findsOneWidget);

    // Structural, not behavioural. The boundary that becomes the PNG is the
    // nearest one above the canvas; the handles must not be inside it.
    //
    // Asserted this way because the alternative — deselecting before
    // rasterising and hoping the frame lands first — is the version that
    // silently ships a selection outline to every guest when it does not.
    final canvasBoundary = find
        .ancestor(
          of: find.byType(InviteCanvas),
          matching: find.byType(RepaintBoundary),
        )
        .first;

    expect(
      find.descendant(
        of: canvasBoundary,
        matching: find.byType(InviteLayerHandles),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: canvasBoundary, matching: find.byType(InviteCanvas)),
      findsOneWidget,
    );
  });

  testWidgets('renders on a dark page', (tester) async {
    await pump(tester, theme: AppTheme.dark);
    await addText(tester, 'Dark');

    expect(tester.takeException(), isNull);
    expect(find.byType(InviteStyleBar), findsOneWidget);
  });
}
