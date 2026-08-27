import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../domain/invite_design.dart';
import 'invite_canvas.dart';

/// Selection chrome and direct manipulation for one layer.
///
/// Sits above [InviteCanvas] rather than inside it, so the text the host sees
/// while editing is drawn by exactly the code that draws the exported PNG.
/// Handles that lived in the canvas would either appear in the export or need
/// a second, subtly different layout to hide them.
class InviteLayerHandles extends StatefulWidget {
  const InviteLayerHandles({
    required this.layer,
    required this.canvasWidth,
    required this.onGestureStart,
    required this.onDrag,
    required this.onResize,
    required this.onRotate,
    required this.onEditText,
    required this.onDelete,
    super.key,
  });

  final TextLayer layer;
  final double canvasWidth;

  final VoidCallback onGestureStart;

  /// Fractions of the canvas, not pixels.
  final void Function(double ddx, double ddy) onDrag;

  /// The width factor the layer had when the drag began, and how far it has
  /// moved since, as a fraction of the canvas width.
  final void Function(double startWidthFactor, double delta) onResize;

  /// Turns.
  final ValueChanged<double> onRotate;

  final VoidCallback onEditText;
  final VoidCallback onDelete;

  /// Big enough to grab on a phone without swamping a small layer.
  static const handleSize = 28.0;

  /// How far the widget's own box extends past the text it wraps.
  ///
  /// The handles sit *inside* this margin rather than hanging off the edge of
  /// the text box. A child painted outside its parent's bounds is not hit
  /// tested — it draws, and every tap goes straight through it to whatever is
  /// behind — so handles at negative offsets look correct and do nothing.
  static const pad = handleSize / 2;

  @override
  State<InviteLayerHandles> createState() => _InviteLayerHandlesState();
}

class _InviteLayerHandlesState extends State<InviteLayerHandles> {
  double _startWidthFactor = 0;
  double _draggedDx = 0;
  double _startRotation = 0;
  Offset _rotateOrigin = Offset.zero;

  /// True for the length of a resize drag. See [InviteTextLayerView.measure].
  bool _resizing = false;

  double get _canvasHeight => widget.canvasWidth / InviteDesign.aspectRatio;

  /// The layer's centre in canvas pixels.
  Offset get _centre => Offset(
    widget.layer.dx * widget.canvasWidth,
    widget.layer.dy * _canvasHeight,
  );

  /// The unrotated box the text occupies.
  ///
  /// Delegated to the canvas's own measurement rather than repeated here: two
  /// layout calls with the same inputs is one refactor away from being two
  /// layout calls with different ones, and the outline would then drift off
  /// the words.
  Size _measure() => InviteTextLayerView(
    layer: widget.layer,
    canvasWidth: widget.canvasWidth,
  ).measure(context, full: _resizing);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = _measure();
    final centre = _centre;
    const pad = InviteLayerHandles.pad;

    return Positioned(
      // Inflated by [pad] on every side so the handles have room inside the
      // box rather than outside it.
      left: centre.dx - size.width / 2 - pad,
      top: centre.dy - size.height / 2 - pad,
      width: size.width + pad * 2,
      height: size.height + pad * 2,
      child: Transform.rotate(
        angle: widget.layer.rotation * 2 * math.pi,
        child: Stack(
          children: [
            // The drag surface is the text's own box, so grabbing a layer means
            // touching it — not hunting for a handle.
            Positioned(
              left: pad,
              top: pad,
              width: size.width,
              height: size.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: widget.onEditText,
                onPanStart: (_) => widget.onGestureStart(),
                onPanUpdate: (details) => widget.onDrag(
                  details.delta.dx / widget.canvasWidth,
                  details.delta.dy / _canvasHeight,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            _corner(
              top: true,
              left: true,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: _disc(Icons.close, colors.error, colors.onError),
              ),
            ),
            _corner(
              top: true,
              left: false,
              child: GestureDetector(
                onTap: widget.onEditText,
                child: _disc(Icons.edit, colors.primary, colors.onPrimary),
              ),
            ),
            _corner(top: false, left: true, child: _rotateHandle(colors)),
            _corner(top: false, left: false, child: _resizeHandle(colors)),
          ],
        ),
      ),
    );
  }

  /// Places a handle in one corner of the inflated box.
  Widget _corner({
    required bool top,
    required bool left,
    required Widget child,
  }) => Positioned(
    left: left ? 0 : null,
    right: left ? null : 0,
    top: top ? 0 : null,
    bottom: top ? null : 0,
    child: child,
  );

  /// Bottom-right widens the box.
  ///
  /// Width only, and deliberately: there is no independent height to drag —
  /// how tall a layer is falls out of its type size and how many lines it
  /// wraps to. Type size is the slider.
  Widget _resizeHandle(ColorScheme colors) {
    return GestureDetector(
      onPanStart: (_) {
        setState(() {
          _resizing = true;
          _startWidthFactor = widget.layer.widthFactor;
          _draggedDx = 0;
        });
        widget.onGestureStart();
      },
      onPanUpdate: (details) {
        _draggedDx += details.delta.dx;
        // Doubled: the box is centred on the layer, so pulling the right edge
        // out by one pixel has to add one on the left too, or the text would
        // slide sideways as it grew.
        widget.onResize(_startWidthFactor, _draggedDx * 2 / widget.canvasWidth);
      },
      onPanEnd: (_) => setState(() => _resizing = false),
      onPanCancel: () => setState(() => _resizing = false),
      child: _disc(Icons.swap_horiz, colors.primary, colors.onPrimary),
    );
  }

  Widget _rotateHandle(ColorScheme colors) {
    return GestureDetector(
      onPanStart: (details) {
        _startRotation = widget.layer.rotation;
        _rotateOrigin = details.globalPosition;
        widget.onGestureStart();
      },
      onPanUpdate: (details) {
        final centreGlobal = _globalCentre();
        if (centreGlobal == null) return;
        final from = _rotateOrigin - centreGlobal;
        final to = details.globalPosition - centreGlobal;
        final delta =
            (math.atan2(to.dy, to.dx) - math.atan2(from.dy, from.dx)) /
            (2 * math.pi);
        widget.onRotate(_startRotation + delta);
      },
      child: _disc(Icons.rotate_right, colors.primary, colors.onPrimary),
    );
  }

  /// The layer's centre in global coordinates, for the rotate maths.
  ///
  /// Read from the render tree rather than computed, because this widget is
  /// already inside a [Transform.rotate] — deriving it from the canvas offset
  /// would ignore the rotation in progress and make the handle fight the
  /// gesture.
  Offset? _globalCentre() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  Widget _disc(IconData icon, Color background, Color foreground) => Container(
    width: InviteLayerHandles.handleSize,
    height: InviteLayerHandles.handleSize,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: background,
      boxShadow: [
        BoxShadow(
          // Lifted off the card so a handle stays visible over dark artwork.
          color: context.colors.shadow,
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Icon(icon, size: AppSizes.iconSm, color: foreground),
  );
}
