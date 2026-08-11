import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Text that assembles itself out of a drifting cloud of particles.
///
/// The particles are not decorative dots scattered near the words — each one
/// has a target that is a real pixel of a real glyph, so the cloud resolves
/// into the actual letterforms of [text] in the actual [style].
///
/// ## How the targets are found
///
/// Flutter exposes no public API for glyph outlines, so the text is rasterised
/// once into an offscreen image and the opaque pixels of that raster are
/// sampled on a grid ([_gridStep]). Each sample becomes one particle's
/// destination. This costs one readback at build time and nothing per frame.
///
/// ## What the animation drives
///
/// A single [animation] from 0 → 1 drives the whole effect. The word assembles
/// **one letter at a time in reading order**: every particle is tagged with the
/// character its target pixel falls under, and that tag — not chance — sets
/// when it sets off. Successive letters overlap somewhat, so the effect reads
/// as a wave crossing the word rather than as a metronome.
///
/// Once every letter has landed, the real [Text] cross-fades in as the
/// particles dissolve, leaving crisp selectable glyphs rather than a permanent
/// field of dots.
///
/// The real [Text] is in the tree the whole time, merely transparent, so
/// screen readers and `find.text` see the words from the first frame.
///
/// Honours the platform "reduce motion" setting by rendering plain [Text].
class ParticleText extends StatefulWidget {
  const ParticleText({
    super.key,
    required this.text,
    required this.style,
    required this.animation,
    this.seed = 0,
  });

  final String text;
  final TextStyle style;

  /// Drives the whole effect, 0 → 1.
  final Animation<double> animation;

  /// Seeds the scatter. Fixed rather than time-based so a golden test or a
  /// second run reproduces the same cloud; vary it between instances so two
  /// lines of text do not scatter identically.
  final int seed;

  @override
  State<ParticleText> createState() => _ParticleTextState();
}

class _ParticleTextState extends State<ParticleText> {
  /// Sample the raster every N logical pixels. 2 keeps thin serifs and the
  /// tittles on "i" intact; 3 starts to shred them, and 1 quadruples the
  /// particle count for detail no one can see at this size.
  static const _gridStep = 2;

  /// A pixel counts as part of a glyph above this alpha. Deliberately low so
  /// antialiased stroke edges contribute — they are what makes the assembled
  /// word read as a word rather than a stencil.
  static const _inkThreshold = 90;

  /// Ceiling on particle count. Past this the effect reads no better and the
  /// per-frame position loop starts to matter; the grid coarsens instead.
  static const _maxParticles = 1400;

  _ParticleField? _field;
  Object? _pendingBuild;

  late final CurvedAnimation _textFade = CurvedAnimation(
    parent: widget.animation,
    // Starts at `_ParticleField._formEnd` — the moment the last letter lands.
    // Sharpening any earlier would fade crisp glyphs up underneath letters
    // still assembling, which reads as a blurry double exposure.
    curve: const Interval(0.70, 0.96, curve: Curves.easeIn),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleBuild();
  }

  @override
  void didUpdateWidget(ParticleText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.style != widget.style) _scheduleBuild();
  }

  @override
  void dispose() {
    _pendingBuild = null;
    _textFade.dispose();
    super.dispose();
  }

  /// Rasterises and samples off the build phase.
  ///
  /// The readback is asynchronous, so a token guards against an older build
  /// landing after a newer one and installing a stale field.
  void _scheduleBuild() {
    if (MediaQuery.disableAnimationsOf(context)) return;

    final token = Object();
    _pendingBuild = token;
    final field = _sampleGlyphs(
      text: widget.text,
      style: widget.style,
      direction: Directionality.of(context),
      scaler: MediaQuery.textScalerOf(context),
      seed: widget.seed,
    );
    field.then((value) {
      if (!mounted || _pendingBuild != token) return;
      setState(() => _field = value);
    });
  }

  static Future<_ParticleField?> _sampleGlyphs({
    required String text,
    required TextStyle style,
    required TextDirection direction,
    required TextScaler scaler,
    required int seed,
  }) async {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout();

    final width = painter.width.ceil();
    final height = painter.height.ceil();
    if (width <= 0 || height <= 0) {
      painter.dispose();
      return null;
    }

    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    // Read the glyph boxes before the painter goes — they are what tags each
    // particle with its letter.
    final columnLetter = _letterPerColumn(painter, text, width);
    picture.dispose();
    image.dispose();
    painter.dispose();
    if (bytes == null) return null;

    final pixels = bytes.buffer.asUint8List();
    // Coarsen the grid rather than truncate the list: dropping the tail would
    // leave the end of the word bare while the start was fully formed.
    var step = _gridStep;
    List<Offset> targets;
    List<int> letters;
    do {
      targets = <Offset>[];
      letters = <int>[];
      for (var y = 0; y < height; y += step) {
        for (var x = 0; x < width; x += step) {
          if (pixels[(y * width + x) * 4 + 3] > _inkThreshold) {
            targets.add(Offset(x + 0.5, y + 0.5));
            letters.add(columnLetter[x]);
          }
        }
      }
      step++;
    } while (targets.length > _maxParticles);

    return _ParticleField.scatter(
      targets: targets,
      letters: letters,
      size: Size(width.toDouble(), height.toDouble()),
      seed: seed,
    );
  }

  /// Maps every pixel column of the raster to the letter that owns it, numbered
  /// in reading order.
  ///
  /// Tagging by column rather than per pixel is what keeps this cheap: glyphs
  /// on a single line do not overlap horizontally, so the column alone settles
  /// which letter a pixel belongs to.
  ///
  /// Numbered in *reading* order rather than left-to-right, so a right-to-left
  /// script assembles the way it is read. Whitespace is skipped — a space owns
  /// no ink, and giving it a slot would stall the wave mid-phrase for no
  /// visible reason. Columns falling outside every glyph box (accents, italic
  /// overhang) attach to the nearest letter.
  static Int32List _letterPerColumn(
    TextPainter painter,
    String text,
    int width,
  ) {
    final spans = <({int order, double left, double right})>[];
    for (var i = 0; i < text.length; i++) {
      if (text[i].trim().isEmpty) continue;
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );
      if (boxes.isEmpty) continue;
      var left = boxes.first.left;
      var right = boxes.first.right;
      for (final box in boxes.skip(1)) {
        left = math.min(left, box.left);
        right = math.max(right, box.right);
      }
      spans.add((order: spans.length, left: left, right: right));
    }

    final columns = Int32List(width);
    if (spans.isEmpty) return columns;

    for (var x = 0; x < width; x++) {
      var nearest = 0;
      var nearestGap = double.infinity;
      for (final span in spans) {
        final gap = x < span.left
            ? span.left - x
            : (x > span.right ? x - span.right : 0.0);
        if (gap < nearestGap) {
          nearestGap = gap;
          nearest = span.order;
        }
        if (gap == 0) break;
      }
      columns[x] = nearest;
    }
    return columns;
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(widget.text, style: widget.style);
    if (MediaQuery.disableAnimationsOf(context)) return text;

    // The particles *are* the letters, so they are painted in the letters' own
    // colour — there is no separate token for them, and inventing a fallback
    // literal here would put a colour outside the palette. Resolving through
    // the inherited DefaultTextStyle covers a caller who sets the colour there
    // rather than on [style]; if neither does, the cloud is simply skipped and
    // the text renders normally.
    final field = _field;
    final color =
        widget.style.color ?? DefaultTextStyle.of(context).style.color;

    return Stack(
      alignment: Alignment.center,
      // Particles start up to [_ParticleField._maxDrift] outside the word, and
      // a Stack clips to its own bounds by default — which would shear the
      // cloud off at the text box and leave dots appearing at the edges
      // instead of flying in from the surrounding space.
      clipBehavior: Clip.none,
      children: [
        FadeTransition(opacity: _textFade, child: text),
        if (field != null && color != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ParticlePainter(
                  field: field,
                  animation: widget.animation,
                  color: color,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Where every particle starts, where it lands, and when it sets off.
///
/// Flat [Float32List]s rather than a list of objects: the painter walks all of
/// this on every frame, and an `Offset` per particle per frame is a lot of
/// short-lived allocation for a 60 Hz path.
class _ParticleField {
  _ParticleField._({
    required this.targets,
    required this.starts,
    required this.delays,
    required this.size,
  }) : scratch = Float32List(targets.length);

  /// Scatters each target to a random start on a ring around it, and sets it
  /// off when its own letter's turn comes.
  ///
  /// A ring, not a uniform box: drawing from a box leaves a visible rectangle
  /// of dust before the word forms, whereas per-particle rings around glyphs
  /// read as the letters themselves shaking apart.
  factory _ParticleField.scatter({
    required List<Offset> targets,
    required List<int> letters,
    required Size size,
    required int seed,
  }) {
    final random = math.Random(seed);
    final count = targets.length;
    final targetXY = Float32List(count * 2);
    final startXY = Float32List(count * 2);
    final delays = Float32List(count);

    // Spread however many letters there are across the forming window, so a
    // long tagline and a short wordmark both finish at [_formEnd]. The letters
    // simply overlap more when there are more of them.
    final letterCount = letters.isEmpty ? 1 : letters.reduce(math.max) + 1;
    final step = letterCount > 1
        ? (_formEnd - _flight - _jitter) / (letterCount - 1)
        : 0.0;

    for (var i = 0; i < count; i++) {
      final target = targets[i];
      final drift = Offset.fromDirection(
        random.nextDouble() * 2 * math.pi,
        _minDrift + random.nextDouble() * (_maxDrift - _minDrift),
      );
      targetXY[i * 2] = target.dx;
      targetXY[i * 2 + 1] = target.dy;
      startXY[i * 2] = target.dx + drift.dx;
      startXY[i * 2 + 1] = target.dy + drift.dy;
      // Letter order sets the beat; the jitter keeps one letter's own dots
      // from moving in lockstep, which would read as a sliding stamp rather
      // than as particles.
      delays[i] = letters[i] * step + random.nextDouble() * _jitter;
    }

    return _ParticleField._(
      targets: targetXY,
      starts: startXY,
      delays: delays,
      size: size,
    );
  }

  /// How far a particle starts from its target, in logical pixels.
  static const _minDrift = 18.0;
  static const _maxDrift = 96.0;

  /// Fraction of the animation one particle spends in flight. Short relative
  /// to the whole, so a letter has visibly landed before the next few finish.
  static const _flight = 0.22;

  /// Random spread applied within a single letter, on top of its beat.
  static const _jitter = 0.05;

  /// The point by which every letter has landed. The remainder of the
  /// animation is the hand-over to crisp text, so nothing may still be flying
  /// after this or it would be erased mid-air by the dissolve.
  static const _formEnd = 0.70;

  /// Flight time as a fraction of the animation.
  static double get travel => _flight;

  final Float32List targets;
  final Float32List starts;
  final Float32List delays;

  /// Reused every frame for the interpolated positions handed to the canvas.
  final Float32List scratch;

  final Size size;

  int get count => delays.length;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.field,
    required this.animation,
    required this.color,
  }) : super(repaint: animation);

  final _ParticleField field;
  final Animation<double> animation;
  final Color color;

  /// Diameter of one particle. Slightly wider than [_ParticleTextState
  /// ._gridStep] so the landed cloud closes into solid strokes instead of a
  /// halftone screen.
  static const _dotSize = 2.6;

  final Paint _paint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = _dotSize
    ..isAntiAlias = true;

  /// Opacity of the cloud as a whole: a quick fade up, then out as the real
  /// text takes over. Ends at zero so nothing is painted over crisp glyphs.
  ///
  /// The fade-out starts only after `_ParticleField._formEnd`, once the last
  /// letter has landed. Beginning it any earlier dissolves the tail of the
  /// word while it is still in the air, which looks like the animation broke.
  static double _envelope(double t) {
    if (t < 0.08) return t / 0.08;
    if (t > 0.74) return math.max(0, (1 - t) / 0.26);
    return 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final alpha = _envelope(t);
    if (alpha <= 0) return;

    // The raster was taken at the text's own size; if the Stack handed us a
    // different box, centre in it rather than letting the cloud drift off the
    // letters it is supposed to be forming.
    final dx = (size.width - field.size.width) / 2;
    final dy = (size.height - field.size.height) / 2;

    final out = field.scratch;
    for (var i = 0; i < field.count; i++) {
      final u = Curves.easeOutCubic.transform(
        ((t - field.delays[i]) / _ParticleField.travel).clamp(0.0, 1.0),
      );
      final x = i * 2;
      final y = x + 1;
      out[x] = field.starts[x] + (field.targets[x] - field.starts[x]) * u + dx;
      out[y] = field.starts[y] + (field.targets[y] - field.starts[y]) * u + dy;
    }

    // One call for the whole cloud. Per-particle colour would mean drawAtlas
    // and a sprite sheet; the stagger already supplies the visual variety.
    canvas.drawRawPoints(
      ui.PointMode.points,
      out,
      _paint..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.field != field || old.color != color;
}
