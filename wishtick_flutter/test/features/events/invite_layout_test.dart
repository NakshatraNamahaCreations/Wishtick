import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/events/domain/event.dart';
import 'package:wishtick_flutter/features/events/domain/invite_design.dart';

/// A layout applied to a background — the composition every preview and every
/// designer session now starts from.
///
/// These are the properties that fail silently: a line placed on the bunting,
/// an id that collides with what the editor generates next, or "null" printed
/// where a venue should be. None of them throws.
void main() {
  const facts = InviteFacts(
    title: "Siya's 24th",
    dateLine: 'Sun, 19 Jul • 8:00 pm',
    venue: 'Mysore Socials',
  );

  group('every line lands inside the safe area', () {
    for (final background in InviteBackgrounds.all) {
      for (final layout in InviteLayouts.all) {
        test('${layout.label} on ${background.label}', () {
          final design = InviteDesign.fromLayout(
            background: background,
            layout: layout,
            facts: facts,
          );
          final area = background.safeArea;

          expect(design.layers, isNotEmpty);
          for (final layer in design.layers) {
            // The centre, and the box around it. Both backgrounds are frames —
            // bunting above, baubles below — and a centre inside the area
            // with a box that reaches past it still lands text on the art.
            expect(layer.dy, inInclusiveRange(area.top, area.bottom));
            expect(layer.dx, closeTo(area.center.dx, 1e-9));
            expect(
              layer.widthFactor,
              lessThanOrEqualTo(area.width + 1e-9),
              reason: '${layer.id} is wider than the safe area',
            );
          }
        });
      }
    }
  });

  test('ids never collide with the ones the designer generates', () {
    // The controller numbers its own layers `layer_0`, `layer_1`… from zero
    // regardless of what it was seeded with. A pre-placed `layer_0` would be
    // silently shadowed by the first line the host adds.
    for (final layout in InviteLayouts.all) {
      final design = InviteDesign.fromLayout(
        background: InviteBackgrounds.happyBirthday,
        layout: layout,
        facts: facts,
      );
      for (final layer in design.layers) {
        expect(layer.id, startsWith('tpl_'), reason: layout.key);
        expect(layer.id, isNot(startsWith('layer_')));
      }
      // And unique within one design.
      final ids = design.layers.map((l) => l.id).toSet();
      expect(ids, hasLength(design.layers.length));
    }
  });

  test('the event fills the lines: title, date, venue', () {
    final design = InviteDesign.fromLayout(
      background: InviteBackgrounds.wishes,
      layout: InviteLayouts.classic,
      facts: facts,
    );
    final texts = design.layers.map((l) => l.text).toList();

    expect(texts, contains("Siya's 24th"));
    expect(texts, contains('Sun, 19 Jul • 8:00 pm'));
    expect(texts, contains('Mysore Socials'));
    // The eyebrow is the layout's own copy, uppercased as it asked.
    expect(texts, contains("YOU'RE INVITED"));
  });

  test('a missing venue drops the line rather than printing blank', () {
    final design = InviteDesign.fromLayout(
      background: InviteBackgrounds.wishes,
      layout: InviteLayouts.classic,
      facts: const InviteFacts(title: 'T', dateLine: 'D'),
    );

    expect(design.layers.where((l) => l.id == 'tpl_venue'), isEmpty);
    expect(design.layers.map((l) => l.text), isNot(contains('null')));
    expect(design.layers.map((l) => l.text), isNot(contains('')));
  });

  test('colours come from the background, not the layout', () {
    // Legibility is the picture's property. The same style on the two
    // backgrounds has to pick up each one's ink and accent.
    for (final background in InviteBackgrounds.all) {
      final design = InviteDesign.fromLayout(
        background: background,
        layout: InviteLayouts.classic,
        facts: facts,
      );
      final colours = design.layers.map((l) => l.color).toSet();
      expect(colours, contains(background.ink));
      expect(colours, contains(background.accent));
    }
    expect(
      InviteBackgrounds.happyBirthday.accent,
      isNot(InviteBackgrounds.wishes.accent),
    );
  });

  test('every layout names only fonts the designer offers', () {
    // A typo here renders in the fallback face with no error anywhere — the
    // style just quietly is not the style.
    final known = InviteFonts.all.map((f) => f.key).toSet();
    for (final layout in InviteLayouts.all) {
      for (final spec in layout.layers) {
        expect(known, contains(spec.fontKey), reason: layout.key);
      }
    }
  });

  test('Playful is birthdays only; the rest are for any occasion', () {
    expect(
      InviteLayouts.forType(EventType.anniversary).map((l) => l.key),
      isNot(contains('playful')),
    );
    expect(
      InviteLayouts.forType(EventType.birthday).map((l) => l.key),
      contains('playful'),
    );
    expect(InviteLayouts.forType(null), hasLength(InviteLayouts.all.length));
  });

  test('the composed design survives a round trip through JSON', () {
    // What the designer hands back is what the event would reopen from.
    final design = InviteDesign.fromLayout(
      background: InviteBackgrounds.happyBirthday,
      layout: InviteLayouts.playful,
      facts: facts,
    );
    expect(InviteDesign.fromJson(design.toJson()), design);
  });

  group('the host line', () {
    // The host is whoever created the event, never `personName` — that is
    // who the party is *for*.
    const hosted = InviteFacts(
      title: "Siya's 24th",
      dateLine: 'D',
      venue: 'V',
      host: 'Hosted by Rohan',
    );

    test('names the host when there is one', () {
      for (final layout in [
        InviteLayouts.classic,
        InviteLayouts.script,
        InviteLayouts.modern,
      ]) {
        final design = InviteDesign.fromLayout(
          background: InviteBackgrounds.wishes,
          layout: layout,
          facts: hosted,
        );
        expect(
          design.layers.map((l) => l.text),
          contains('Hosted by Rohan'),
          reason: layout.key,
        );
      }
    });

    test('is dropped when there is nobody to name', () {
      // A self-event, or an account with no name: either way the fact is null
      // and the line is left out rather than printed blank.
      final design = InviteDesign.fromLayout(
        background: InviteBackgrounds.wishes,
        layout: InviteLayouts.classic,
        facts: const InviteFacts(title: 'T', dateLine: 'D'),
      );
      expect(design.layers.where((l) => l.id == 'tpl_host'), isEmpty);
    });

    test('is never the event personName', () {
      // Nothing in the composition reads personName: the facts carry a
      // pre-phrased host line or nothing, so the layout cannot get it wrong.
      final fields = InviteFacts.placeholder.toString();
      expect(fields, isNot(contains('personName')));
      expect(InviteFacts.placeholder.forRole(LayerRole.host), 'Hosted by you');
    });
  });

  test('a layer keeps its proportions at any width', () {
    // Sizes are fractions of canvas width, so a card looks the same at the
    // thumbnail and at export — the reason nothing here is in pixels.
    final design = InviteDesign.fromLayout(
      background: InviteBackgrounds.wishes,
      layout: InviteLayouts.bold,
      facts: facts,
    );
    final headline = design.layers.firstWhere((l) => l.id == 'tpl_headline');
    expect(
      headline.fontSize,
      inInclusiveRange(TextLayer.minFontSize, TextLayer.maxFontSize),
    );
    expect(headline.text, "SIYA'S 24TH");
    expect(headline.align, LayerAlign.center);
    expect(headline.rotation, 0);
    expect(const Color(0xFF000000), isA<Color>()); // keeps the import honest
  });
}
