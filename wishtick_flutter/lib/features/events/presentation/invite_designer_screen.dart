import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/invite_design.dart';
import 'invite_designer_controller.dart';
import 'widgets/invite_canvas.dart';
import 'widgets/invite_layer_handles.dart';
import 'widgets/invite_style_bar.dart';

/// Rasterises a laid-out canvas to PNG bytes.
///
/// A named seam rather than a private method so a widget test can stand in for
/// it. `RenderRepaintBoundary.toImage` needs the engine to have actually
/// rasterised a frame, which the automated test binding never does — so the
/// pixels themselves are checked on a device, and everything around them
/// (which boundary, at what ratio, and what happens to the result) is checked
/// here.
typedef InviteCardRenderer =
    Future<Uint8List?> Function(RenderRepaintBoundary boundary);

/// The real one.
Future<Uint8List?> rasteriseInviteCard(RenderRepaintBoundary boundary) async {
  final image = await boundary.toImage(
    pixelRatio: inviteExportPixelRatio(boundary.size.width),
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// How much to scale the on-screen canvas by to reach
/// [InviteDesign.exportWidth].
///
/// Derived from the canvas's actual width rather than fixed, because the editor
/// sizes itself to the device: a hard-coded ratio would export a different card
/// on a tablet than on a handset.
double inviteExportPixelRatio(double onScreenWidth) =>
    onScreenWidth <= 0 ? 1 : InviteDesign.exportWidth / onScreenWidth;

/// The invitation designer.
///
/// The background is whatever the chosen template fixed; everything above it is
/// the host's. Text is added, dragged, scaled, rotated and styled per layer,
/// and the finished card leaves as a PNG — the phone renders it, so what is on
/// screen here is exactly what a guest receives.
class InviteDesignerScreen extends ConsumerStatefulWidget {
  const InviteDesignerScreen({
    required this.initial,
    this.onDone,
    this.renderer = rasteriseInviteCard,
    super.key,
  });

  final InviteDesign initial;

  /// Given the finished card and the design that produced it. The design comes
  /// back too so the invitation can be reopened and edited rather than
  /// re-made — a layered editor that cannot reopen its own work is a one-shot.
  final Future<void> Function(Uint8List png, InviteDesign design)? onDone;

  /// Overridden only by tests. See [InviteCardRenderer].
  final InviteCardRenderer renderer;

  @override
  ConsumerState<InviteDesignerScreen> createState() =>
      _InviteDesignerScreenState();
}

class _InviteDesignerScreenState extends ConsumerState<InviteDesignerScreen> {
  /// How long Done will wait for outstanding typefaces. Long enough for a face
  /// just picked to arrive on a normal connection, short enough that a bad one
  /// does not look like the button is broken.
  static const _fontWait = Duration(seconds: 2);

  final _canvasKey = GlobalKey();
  bool _exporting = false;

  InviteDesignerController get _controller =>
      ref.read(inviteDesignerProvider(widget.initial).notifier);

  // ── Text entry ────────────────────────────────────────────────────────────

  Future<void> _promptForText(TextLayer layer) async {
    final next = await showDialog<String>(
      context: context,
      builder: (_) => _TextLayerDialog(initial: layer.text),
    );
    if (next == null) return;

    final trimmed = next.trim();
    // An empty layer is invisible and unselectable — it would be a handle
    // floating over nothing. Clearing the text removes the layer instead.
    if (trimmed.isEmpty) {
      _controller.remove(layer.id);
      return;
    }
    _controller.edit(layer.id, (l) => l.copyWith(text: trimmed));
  }

  Future<void> _addText() async {
    final layer = _controller.addText();
    await _promptForText(layer);
  }

  // ── Export ────────────────────────────────────────────────────────────────

  /// Rasterises the canvas at [InviteDesign.exportWidth].
  ///
  /// The pixel ratio is derived from the canvas's actual on-screen width rather
  /// than fixed, because the editor sizes itself to the phone: a hard-coded
  /// ratio would export a different card on a tablet than on a handset.
  Future<Uint8List?> _renderCard() {
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return Future.value();
    return widget.renderer(boundary);
  }

  Future<void> _done() async {
    if (_exporting) return;
    // No deselect and no waiting for a frame: every piece of selection chrome
    // — the outline, the four handles, the tap targets — is a *sibling* of the
    // RepaintBoundary rather than a child of it, so none of it can reach the
    // raster. See `_canvas`, and the structural test that pins it there.
    setState(() => _exporting = true);

    try {
      // Before rasterising, not after: a Google face still downloading renders
      // as the fallback, and a card rasterised in that moment would bake the
      // wrong typeface into the PNG every guest receives. This is precisely
      // what `pendingFonts` exists for.
      try {
        await GoogleFonts.pendingFonts().timeout(_fontWait);
      } catch (_) {
        // Bounded and swallowed, because this can both hang and throw and
        // neither may cost the host their invitation:
        //
        //  * it *rejects* when a face cannot be fetched — offline, or the CDN
        //    unreachable — and letting that escape would make Done do nothing
        //    at all, with no message, whenever the network is down;
        //  * it waits on every face the picker has previewed, not just the two
        //    on the card, so an unbounded wait would hold the export behind
        //    two dozen downloads the design does not use.
        //
        // Either way the affected face is already drawn in the fallback on the
        // canvas in front of the host, so the export still matches what they
        // approved.
      }
      if (!mounted) return;

      final png = await _renderCard();
      if (!mounted) return;
      if (png == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not render the invitation.')),
        );
        return;
      }
      final design = ref.read(inviteDesignerProvider(widget.initial)).design;
      await widget.onDone?.call(png, design);
      if (mounted) unawaited(Navigator.of(context).maybePop(design));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(inviteDesignerProvider(widget.initial));
    final selected = state.selected;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Design invitation'),
        actions: [
          IconButton(
            onPressed: state.canUndo ? _controller.undo : null,
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
          ),
          TextButton(
            onPressed: _exporting ? null : () => unawaited(_done()),
            child: _exporting
                ? const SizedBox(
                    width: AppSizes.iconMd,
                    height: AppSizes.iconMd,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AspectRatio(
                  aspectRatio: InviteDesign.aspectRatio,
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        _canvas(state, selected, constraints.maxWidth),
                  ),
                ),
              ),
            ),
          ),
          if (selected != null)
            InviteStyleBar(
              layer: selected,
              onChange: (next) => _controller.edit(next.id, (_) => next),
              onChangeLive: (next) =>
                  _controller.editLive(next.id, (_) => next),
              onGestureStart: _controller.beginGesture,
              onReorder: ({required forward}) =>
                  _controller.reorder(selected.id, forward: forward),
              onDuplicate: () => _controller.duplicate(selected.id),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => unawaited(_addText()),
                      icon: const Icon(Icons.add, size: AppSizes.iconMd),
                      label: const Text('Add text'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _canvas(InviteDesignerState state, TextLayer? selected, double width) {
    return Stack(
      children: [
        // Tapping the background clears the selection, which is the only way to
        // put the handles away and see the card as a guest will.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _controller.deselect,
            child: RepaintBoundary(
              key: _canvasKey,
              child: InviteCanvas(design: state.design, width: width),
            ),
          ),
        ),
        // Every layer gets a tap target, so an unselected one can be picked up.
        for (final layer in state.design.layers)
          if (layer.id != selected?.id)
            _TapTarget(
              layer: layer,
              canvasWidth: width,
              onTap: () => _controller.select(layer.id),
            ),
        if (selected != null)
          InviteLayerHandles(
            layer: selected,
            canvasWidth: width,
            onGestureStart: _controller.beginGesture,
            onDrag: (ddx, ddy) => _controller.dragBy(selected.id, ddx, ddy),
            onResize: (start, delta) =>
                _controller.resizeTo(selected.id, start, delta),
            onRotate: (turns) => _controller.rotateTo(selected.id, turns),
            onEditText: () => unawaited(_promptForText(selected)),
            onDelete: () => _controller.remove(selected.id),
          ),
      ],
    );
  }
}

/// An invisible hit area over an unselected layer.
class _TapTarget extends StatelessWidget {
  const _TapTarget({
    required this.layer,
    required this.canvasWidth,
    required this.onTap,
  });

  final TextLayer layer;
  final double canvasWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The same measurement the canvas and the handles use, so an unselected
    // layer is grabbed exactly where its words are.
    final box = InviteTextLayerView(
      layer: layer,
      canvasWidth: canvasWidth,
    ).measure(context);

    final height = canvasWidth / InviteDesign.aspectRatio;
    return Positioned(
      left: layer.dx * canvasWidth - box.width / 2,
      top: layer.dy * height - box.height / 2,
      width: box.width,
      height: box.height,
      child: Transform.rotate(
        angle: layer.rotation * 2 * 3.1415926535897932,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Asks for a layer's words.
///
/// A widget of its own rather than an inline builder so the
/// [TextEditingController] is disposed by the element that used it. Disposing
/// it straight after `showDialog` returns looks right and is not: the route is
/// still playing its exit animation, and the field it is attached to rebuilds
/// at least once more against a controller that has already gone.
class _TextLayerDialog extends StatefulWidget {
  const _TextLayerDialog({required this.initial});

  final String initial;

  @override
  State<_TextLayerDialog> createState() => _TextLayerDialogState();
}

class _TextLayerDialogState extends State<_TextLayerDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit text'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        // Multi-line on purpose: an invitation headline is routinely two lines,
        // and forcing it into one is what makes people fake a break with
        // spaces that then wrap wrongly at another size.
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Your text'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          // Not "Done": the screen's own Done exports the card, and two
          // controls a tap apart that both say Done is how somebody publishes
          // an invitation when they meant to finish a sentence.
          child: const Text('Set text'),
        ),
      ],
    );
  }
}
