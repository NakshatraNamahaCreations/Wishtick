import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/events/domain/invite_design.dart';
import 'package:wishtick_flutter/features/events/presentation/invite_designer_controller.dart';

/// The editing model behind the invitation designer.
///
/// The rules worth pinning are the ones a host loses work to: that a drag does
/// not bury the state they would want back, that undo cannot leave the style
/// bar pointed at a layer that no longer exists, and that no edit can push a
/// layer off the card where it cannot be grabbed again.
void main() {
  const start = InviteDesign.empty('happy_birthday');

  ({ProviderContainer container, InviteDesignerController controller}) build() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return (
      container: container,
      controller: container.read(inviteDesignerProvider(start).notifier),
    );
  }

  InviteDesignerState stateOf(ProviderContainer c) =>
      c.read(inviteDesignerProvider(start));

  group('layers', () {
    test(
      'a new layer lands inside the background safe area, not on the art',
      () {
        final t = build();

        final layer = t.controller.addText('Happy Birthday');

        // happy_birthday_bg is a frame: bunting across the top, lettering along
        // the bottom. Dropping a layer at the image's centre would be fine, but
        // dropping one at the top would land it on the bunting — so placement
        // reads the safe area rather than assuming the middle.
        final safe = InviteBackgrounds.happyBirthday.safeArea;
        expect(layer.dx, safe.center.dx);
        expect(layer.dy, safe.center.dy);
        expect(stateOf(t.container).selectedId, layer.id);
      },
    );

    test(
      'every layer gets its own id, so editing one leaves the other alone',
      () {
        final t = build();

        final first = t.controller.addText('One');
        final second = t.controller.addText('Two');

        expect(first.id, isNot(second.id));
        t.controller.edit(second.id, (l) => l.copyWith(text: 'Changed'));
        final layers = stateOf(t.container).design.layers;
        expect(layers.first.text, 'One');
        expect(layers.last.text, 'Changed');
      },
    );

    test('a duplicate is offset, so it does not hide under the original', () {
      final t = build();
      final source = t.controller.addText('Copy me');

      t.controller.duplicate(source.id);

      final layers = stateOf(t.container).design.layers;
      expect(layers, hasLength(2));
      expect(layers.last.id, isNot(source.id));
      expect(layers.last.text, 'Copy me');
      expect(layers.last.dx, greaterThan(source.dx));
      expect(layers.last.dy, greaterThan(source.dy));
    });

    test(
      'reordering moves a layer through the stack and stops at the ends',
      () {
        final t = build();
        final bottom = t.controller.addText('Bottom');
        final top = t.controller.addText('Top');

        t.controller.reorder(bottom.id, forward: true);
        expect(stateOf(t.container).design.layers.last.id, bottom.id);

        // Already on top — a no-op rather than an error or a wrap-around.
        t.controller.reorder(bottom.id, forward: true);
        expect(stateOf(t.container).design.layers.last.id, bottom.id);
        expect(stateOf(t.container).design.layers.first.id, top.id);
      },
    );

    test('removing clears the selection with it', () {
      final t = build();
      final layer = t.controller.addText();

      t.controller.remove(layer.id);

      expect(stateOf(t.container).design.layers, isEmpty);
      // A style bar editing a layer that is gone would write to nothing.
      expect(stateOf(t.container).selectedId, isNull);
      expect(stateOf(t.container).selected, isNull);
    });
  });

  group('geometry', () {
    test('a drag cannot push a layer off the card', () {
      final t = build();
      final layer = t.controller.addText();

      t.controller.beginGesture();
      t.controller.dragBy(layer.id, 5, 5);

      final moved = stateOf(t.container).selected!;
      // Off the canvas is unrecoverable: there is nothing left to tap to drag
      // it back.
      expect(moved.dx, 1.0);
      expect(moved.dy, 1.0);
    });

    test('the corner handle widens the box and leaves the type alone', () {
      final t = build();
      final layer = t.controller.addText();
      final size = stateOf(t.container).selected!.fontSize;
      final width = stateOf(t.container).selected!.widthFactor;

      t.controller.beginGesture();
      t.controller.resizeTo(layer.id, width, 0.1);

      final resized = stateOf(t.container).selected!;
      expect(resized.widthFactor, closeTo(width + 0.1, 1e-9));
      // The whole point of the change: a headline breaking mid-word used to be
      // fixable only by shrinking the letters, because this handle drove the
      // font size. Type size has its own slider.
      expect(resized.fontSize, size);
    });

    test('the box cannot be dragged past the card or down to nothing', () {
      final t = build();
      final layer = t.controller.addText();

      t.controller.resizeTo(layer.id, 0.5, 10);
      expect(stateOf(t.container).selected!.widthFactor, 1.0);

      t.controller.resizeTo(layer.id, 0.5, -10);
      // A zero-width box would wrap every word onto its own line and leave
      // nothing to grab.
      expect(stateOf(t.container).selected!.widthFactor, 0.1);
    });

    test('a resize is measured from where the drag began, not accumulated', () {
      final t = build();
      final layer = t.controller.addText();

      // Out past the clamp and back again. Accumulating deltas would leave the
      // box stuck at the ceiling for the whole return journey.
      t.controller.resizeTo(layer.id, 0.5, 10);
      t.controller.resizeTo(layer.id, 0.5, 0.2);

      expect(stateOf(t.container).selected!.widthFactor, closeTo(0.7, 1e-9));
    });

    test('type size is clamped at both ends', () {
      final t = build();
      final layer = t.controller.addText();

      t.controller.edit(layer.id, (l) => l.copyWith(fontSize: 99));
      expect(stateOf(t.container).selected!.fontSize, TextLayer.maxFontSize);

      t.controller.edit(layer.id, (l) => l.copyWith(fontSize: 0.0001));
      expect(stateOf(t.container).selected!.fontSize, TextLayer.minFontSize);
    });

    test('rotation snaps to straight, because level by hand is impossible', () {
      final t = build();
      final layer = t.controller.addText();

      t.controller.rotateTo(layer.id, 0.005);
      expect(stateOf(t.container).selected!.rotation, 0.0);

      t.controller.rotateTo(layer.id, 0.2505);
      expect(stateOf(t.container).selected!.rotation, 0.25);

      // Far enough from straight to be a deliberate angle, so it is left alone.
      t.controller.rotateTo(layer.id, 0.1);
      expect(stateOf(t.container).selected!.rotation, closeTo(0.1, 1e-9));
    });

    test('a negative turn comes back as its positive equivalent', () {
      final t = build();
      final layer = t.controller.addText();

      t.controller.rotateTo(layer.id, -0.25);

      // Not -0.25: the rotate handle can be swung either way, and a stored
      // angle outside 0..1 makes every later comparison a special case.
      expect(stateOf(t.container).selected!.rotation, 0.75);
    });
  });

  group('styling', () {
    test('a colour swatch keeps the opacity already set', () {
      final t = build();
      final layer = t.controller.addText();

      t.controller.edit(layer.id, (l) => l.withOpacity(0.5));
      t.controller.edit(layer.id, (l) => l.withColor(const Color(0xFFE5397B)));

      final styled = stateOf(t.container).selected!;
      expect(styled.opacity, closeTo(0.5, 0.01));
      expect(styled.displayColor.toARGB32() & 0x00FFFFFF, 0xE5397B);
    });

    test('an opacity slider keeps the colour already picked', () {
      final t = build();
      final layer = t.controller.addText();

      t.controller.edit(layer.id, (l) => l.withColor(const Color(0xFF3F0E4C)));
      t.controller.edit(layer.id, (l) => l.withOpacity(0.25));

      final styled = stateOf(t.container).selected!;
      expect(styled.displayColor.toARGB32() & 0x00FFFFFF, 0x3F0E4C);
      expect(styled.opacity, closeTo(0.25, 0.01));
    });
  });

  group('undo', () {
    test('a whole drag is one undo, not one per frame', () {
      final t = build();
      final layer = t.controller.addText();
      final before = stateOf(t.container).selected!.dx;

      t.controller.beginGesture();
      for (var i = 0; i < 20; i++) {
        t.controller.dragBy(layer.id, 0.01, 0);
      }
      expect(stateOf(t.container).selected!.dx, greaterThan(before));

      t.controller.undo();

      // One undo puts the layer back where the drag started. Recording every
      // frame would bury the pre-drag state under twenty identical ones and
      // make undo feel broken.
      expect(stateOf(t.container).selected!.dx, closeTo(before, 1e-9));
    });

    test('undo past a delete restores the layer and can reselect it', () {
      final t = build();
      final layer = t.controller.addText('Keep me');
      t.controller.remove(layer.id);

      t.controller.undo();

      expect(stateOf(t.container).design.layers.single.text, 'Keep me');
    });

    test('undo never leaves the selection pointing at a missing layer', () {
      final t = build();
      final first = t.controller.addText('One');
      final second = t.controller.addText('Two');
      expect(stateOf(t.container).selectedId, second.id);

      // Back to the design that had only the first layer.
      t.controller.undo();

      expect(stateOf(t.container).design.layers, hasLength(1));
      expect(stateOf(t.container).selectedId, isNot(second.id));
      expect(stateOf(t.container).selected?.id, anyOf(isNull, first.id));
    });

    test('undo on an untouched design does nothing rather than throwing', () {
      final t = build();

      expect(stateOf(t.container).canUndo, isFalse);
      t.controller.undo();

      expect(stateOf(t.container).design, start);
    });
  });

  group('serialisation', () {
    test(
      'a design round-trips, so an invitation can be reopened and edited',
      () {
        final t = build();
        final layer = t.controller.addText('Happy Birthday');
        t.controller.edit(
          layer.id,
          (l) => l
              .copyWith(
                fontSize: 0.12,
                bold: true,
                italic: true,
                align: LayerAlign.left,
                rotation: 0.25,
                fontKey: InviteFonts.cormorant.key,
              )
              .withColor(const Color(0xFFE5397B))
              .withOpacity(0.8),
        );
        final original = stateOf(t.container).design;

        final restored = InviteDesign.fromJson(original.toJson());

        // Value equality across the whole design, so a field added to the layer
        // and forgotten in toJson fails here rather than silently dropping the
        // host's work on reopen.
        expect(restored, original);
      },
    );

    test(
      'a design naming a background this build does not ship still loads',
      () {
        final restored = InviteDesign.fromJson({
          'background': 'from_a_newer_release',
          'layers': [
            TextLayer.fresh(id: 'l', text: 'Hi', safeArea: Rect.zero).toJson(),
          ],
        });

        expect(restored.background, isNull);
        // The text survives even though the art does not — the canvas draws a
        // plain fallback rather than failing to open the invitation at all.
        expect(restored.layers.single.text, 'Hi');
      },
    );
  });
}
