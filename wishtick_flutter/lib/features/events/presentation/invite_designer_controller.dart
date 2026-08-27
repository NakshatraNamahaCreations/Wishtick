import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/invite_design.dart';

/// The designer's whole editing state.
@immutable
class InviteDesignerState {
  const InviteDesignerState({
    required this.design,
    this.selectedId,
    this.history = const [],
  });

  final InviteDesign design;

  /// Which layer the style bar is editing. Null when nothing is selected, which
  /// is also what hides the handles.
  final String? selectedId;

  /// Previous designs, oldest first. Bounded — see [_historyLimit].
  final List<InviteDesign> history;

  TextLayer? get selected {
    final id = selectedId;
    if (id == null) return null;
    for (final layer in design.layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  bool get canUndo => history.isNotEmpty;

  InviteDesignerState copyWith({
    InviteDesign? design,
    String? selectedId,
    List<InviteDesign>? history,
    bool clearSelection = false,
  }) => InviteDesignerState(
    design: design ?? this.design,
    selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
    history: history ?? this.history,
  );
}

/// Drives the invitation designer.
///
/// Every mutation goes through [_push], which records the design *before* the
/// change. A layered editor without undo is one mis-drag away from losing work
/// the host cannot reconstruct — they cannot re-type a rotation.
///
/// Continuous gestures are the exception: a drag would otherwise push a
/// history entry per frame and bury the previous state under sixty identical
/// ones. Those call [_replace] and take a single snapshot when the gesture
/// starts, via [beginGesture].
class InviteDesignerController extends Notifier<InviteDesignerState> {
  InviteDesignerController(this._initial);

  final InviteDesign _initial;

  /// Deep enough to undo a session's worth of fiddling, shallow enough that a
  /// long editing session does not hold every intermediate design in memory.
  static const _historyLimit = 40;

  var _nextId = 0;

  @override
  InviteDesignerState build() => InviteDesignerState(design: _initial);

  /// Records the current design and applies [next]. For discrete edits.
  void _push(InviteDesign next, {String? select, bool clearSelection = false}) {
    final history = [...state.history, state.design];
    state = state.copyWith(
      design: next,
      history: history.length > _historyLimit
          ? history.sublist(history.length - _historyLimit)
          : history,
      selectedId: select,
      clearSelection: clearSelection,
    );
  }

  /// Applies [next] without touching history. For frames of a live gesture.
  void _replace(InviteDesign next) => state = state.copyWith(design: next);

  InviteDesign _withLayer(TextLayer replacement) => state.design.copyWith(
    layers: [
      for (final layer in state.design.layers)
        if (layer.id == replacement.id) replacement else layer,
    ],
  );

  // ── Selection ─────────────────────────────────────────────────────────────

  void select(String? id) => id == null
      ? state = state.copyWith(clearSelection: true)
      : state = state.copyWith(selectedId: id);

  void deselect() => state = state.copyWith(clearSelection: true);

  // ── Layers ────────────────────────────────────────────────────────────────

  /// Adds a layer in the middle of the background's safe area, selected and
  /// ready to be styled.
  TextLayer addText([String text = 'Your text']) {
    final background = state.design.background;
    final layer = TextLayer.fresh(
      id: 'layer_${_nextId++}',
      text: text,
      safeArea: background?.safeArea ?? const Rect.fromLTRB(0.1, 0.2, 0.9, 0.8),
    );
    _push(
      state.design.copyWith(layers: [...state.design.layers, layer]),
      select: layer.id,
    );
    return layer;
  }

  void remove(String id) {
    _push(
      state.design.copyWith(
        layers: state.design.layers.where((l) => l.id != id).toList(),
      ),
      clearSelection: true,
    );
  }

  void duplicate(String id) {
    final source = state.design.layers.where((l) => l.id == id).firstOrNull;
    if (source == null) return;
    // Offset so the copy is visibly a second layer rather than sitting exactly
    // on the original, where it looks like nothing happened.
    final copy = source.copyWith(dx: source.dx + 0.04, dy: source.dy + 0.03);
    final moved = TextLayer.fromJson({
      ...copy.toJson(),
      'id': 'layer_${_nextId++}',
    });
    _push(
      state.design.copyWith(layers: [...state.design.layers, moved]),
      select: moved.id,
    );
  }

  /// Moves a layer one step through the stack. Later in the list draws on top.
  void reorder(String id, {required bool forward}) {
    final layers = [...state.design.layers];
    final index = layers.indexWhere((l) => l.id == id);
    if (index < 0) return;
    final target = index + (forward ? 1 : -1);
    if (target < 0 || target >= layers.length) return;
    final layer = layers.removeAt(index);
    layers.insert(target, layer);
    _push(state.design.copyWith(layers: layers), select: id);
  }

  // ── Continuous gestures ───────────────────────────────────────────────────

  /// Takes the one history snapshot a drag, pinch or rotate is allowed.
  void beginGesture() =>
      state = state.copyWith(history: [...state.history, state.design]);

  /// Live drag. Deltas are fractions of the canvas, so the caller divides by
  /// the canvas size and this stays resolution-independent.
  void dragBy(String id, double ddx, double ddy) {
    final layer = state.design.layers.where((l) => l.id == id).firstOrNull;
    if (layer == null) return;
    _replace(
      _withLayer(layer.copyWith(dx: layer.dx + ddx, dy: layer.dy + ddy)),
    );
  }

  /// Live resize of the text *box*, not the type.
  ///
  /// Type size has its own slider; the corner handle sets how wide the layer
  /// may run before it wraps. Conflating the two is what makes a headline
  /// break mid-word with no way to fix it but shrinking the letters.
  ///
  /// [delta] is a fraction of the canvas width and is measured from
  /// [startWidthFactor] rather than accumulated, so a drag that runs into the
  /// clamp at one end resumes correctly on the way back.
  void resizeTo(String id, double startWidthFactor, double delta) {
    final layer = state.design.layers.where((l) => l.id == id).firstOrNull;
    if (layer == null) return;
    _replace(_withLayer(layer.copyWith(widthFactor: startWidthFactor + delta)));
  }

  /// Live rotate, in turns.
  ///
  /// Snaps to the nearest straight angle within [_snapTurns]. Getting a layer
  /// exactly level by hand is nearly impossible, and a headline a degree off
  /// looks like a mistake rather than a choice.
  static const _snapTurns = 0.012;

  void rotateTo(String id, double turns) {
    final layer = state.design.layers.where((l) => l.id == id).firstOrNull;
    if (layer == null) return;
    var next = turns % 1.0;
    if (next < 0) next += 1.0;
    for (final straight in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
      if ((next - straight).abs() < _snapTurns) {
        next = straight % 1.0;
        break;
      }
    }
    _replace(_withLayer(layer.copyWith(rotation: next)));
  }

  // ── Styling ───────────────────────────────────────────────────────────────

  void edit(String id, TextLayer Function(TextLayer) change) {
    final layer = state.design.layers.where((l) => l.id == id).firstOrNull;
    if (layer == null) return;
    _push(_withLayer(change(layer)), select: id);
  }

  /// Style changes made while a slider is being dragged — same reasoning as the
  /// gesture methods, paired with [beginGesture].
  void editLive(String id, TextLayer Function(TextLayer) change) {
    final layer = state.design.layers.where((l) => l.id == id).firstOrNull;
    if (layer == null) return;
    _replace(_withLayer(change(layer)));
  }

  // ── History ───────────────────────────────────────────────────────────────

  void undo() {
    if (state.history.isEmpty) return;
    final previous = state.history.last;
    state = InviteDesignerState(
      design: previous,
      history: state.history.sublist(0, state.history.length - 1),
      // The layer that was selected may not exist in the restored design, and
      // a style bar editing a layer that is gone is worse than no style bar.
      selectedId: previous.layers.any((l) => l.id == state.selectedId)
          ? state.selectedId
          : null,
    );
  }
}

/// Scoped to the design being edited, so opening a second invitation does not
/// inherit the first one's undo stack.
///
/// Auto-disposed: an editing session ends when the designer closes, and forty
/// designs' worth of undo history per invitation ever opened is not something
/// to keep. It also means this holds nothing across a sign-out — which the
/// session-scope guard checks, because a provider that outlives its session
/// hands the next user the previous one's work.
final inviteDesignerProvider = NotifierProvider.autoDispose
    .family<InviteDesignerController, InviteDesignerState, InviteDesign>(
      InviteDesignerController.new,
    );
