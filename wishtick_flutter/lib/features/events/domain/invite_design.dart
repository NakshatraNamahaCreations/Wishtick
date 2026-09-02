import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'event.dart';

/// A bundled invitation background.
///
/// The image is fixed once a template is chosen — that is the whole contract
/// with the host: pick the art, then write on it. Backgrounds ship in the app
/// rather than coming from the API because the app is what draws the finished
/// card now; the server stores the PNG the editor exports and never has to own
/// a second copy of the artwork.
@immutable
class InviteBackground {
  const InviteBackground({
    required this.key,
    required this.label,
    required this.asset,
    required this.eventTypes,
    required this.safeArea,
    this.ink = 0xFF1F1F1F,
    this.accent = 0xFF3F0E4C,
  });

  final String key;
  final String label;
  final String asset;

  /// Which occasions offer this design. Empty means every occasion.
  final List<EventType> eventTypes;

  /// Text colours that read on this artwork — the body ink and one accent.
  ///
  /// On the background rather than on a layout because legibility is the
  /// picture's property, not the arrangement's: both bundled backgrounds are
  /// light in the middle (sampled at 250/255 and 237/255 luminance), so dark
  /// ink is right for both, but the accent that harmonises with confetti is
  /// not the one that harmonises with gold.
  final int ink;
  final int accent;

  /// Where text can sit without colliding with the artwork, as a fraction of
  /// the canvas.
  ///
  /// Both bundled backgrounds are frames — bunting and balloons around an open
  /// middle — so a new text layer that landed dead centre of the *image* would
  /// still be right, but one dropped at the top would land on the bunting.
  /// New layers are placed inside this instead.
  final Rect safeArea;

  bool offers(EventType type) =>
      eventTypes.isEmpty || eventTypes.contains(type);
}

/// Every background the app ships.
///
/// A list rather than an enum so adding one is a single entry plus the file —
/// there is no behaviour attached to any particular background.
abstract final class InviteBackgrounds {
  static const happyBirthday = InviteBackground(
    key: 'happy_birthday',
    label: 'Happy Birthday',
    asset: 'assets/images/template_bg/happy_birthday_bg.jpg',
    eventTypes: [EventType.birthday],
    // The bunting reaches ~22% down and the "HAPPY BIRTHDAY" lettering starts
    // at ~78%; balloons hold the sides in from ~12%.
    safeArea: Rect.fromLTRB(0.14, 0.26, 0.86, 0.74),
    // A rose that sits with the balloons rather than against them.
    accent: 0xFFC4304B,
  );

  static const wishes = InviteBackground(
    key: 'wishes',
    label: 'Golden Wishes',
    asset: 'assets/images/template_bg/wishes_bg.jpg',
    eventTypes: [],
    // Hanging lights above, baubles along the floor.
    safeArea: Rect.fromLTRB(0.10, 0.30, 0.90, 0.78),
    // The artwork's own deep gold, sampled from its top corner (#A77536).
    ink: 0xFF3B2A12,
    accent: 0xFFA77536,
  );

  static const all = <InviteBackground>[happyBirthday, wishes];

  static InviteBackground? byKey(String? key) {
    if (key == null) return null;
    for (final background in all) {
      if (background.key == key) return background;
    }
    return null;
  }

  static List<InviteBackground> forType(EventType? type) =>
      type == null ? all : all.where((b) => b.offers(type)).toList();
}

/// How a face is loaded.
enum FontSource {
  /// Shipped in `pubspec.yaml`. Always available, offline included.
  bundled,

  /// Fetched by `google_fonts` on first use and cached on the device.
  ///
  /// The catch that matters here: an unfetched face falls back while it
  /// downloads, and this app *exports* the card — so a rasterise that happened
  /// mid-download would bake the wrong typeface into the PNG a guest receives.
  /// The designer waits on `GoogleFonts.pendingFonts()` before rendering, which
  /// is exactly what that API is for.
  google,
}

/// A typeface offered in the designer.
@immutable
class InviteFont {
  const InviteFont({
    required this.key,
    required this.label,
    required this.family,
    required this.source,
    required this.group,
  });

  const InviteFont.google(this.key, this.label, this.group)
    : family = label,
      source = FontSource.google;

  final String key;
  final String label;

  /// For a bundled face, the `pubspec.yaml` family. For a Google face, the
  /// family name `google_fonts` knows it by — which is the label.
  final String family;

  final FontSource source;

  /// What the dropdown groups it under.
  final String group;

  bool get isBundled => source == FontSource.bundled;
}

/// The catalogue the designer offers.
///
/// Deliberately grouped and finite rather than the whole Google library: a
/// thousand-entry list is not a choice anybody can make, and most of that
/// library is unsuitable for a card read at a glance. These are display and
/// text faces that hold up large, over busy artwork.
///
/// The two bundled faces lead, because they are the only ones guaranteed to be
/// there with no network — see [FontSource.google].
abstract final class InviteFonts {
  static const montserrat = InviteFont(
    key: 'montserrat',
    label: 'Montserrat',
    family: 'Montserrat',
    source: FontSource.bundled,
    group: 'In the app',
  );
  static const cormorant = InviteFont(
    key: 'cormorant',
    label: 'Cormorant',
    family: 'CormorantGaramond',
    source: FontSource.bundled,
    group: 'In the app',
  );

  static const all = <InviteFont>[
    montserrat,
    cormorant,

    // Display — big, characterful, for the headline.
    InviteFont.google('playfair', 'Playfair Display', 'Display'),
    InviteFont.google('abril', 'Abril Fatface', 'Display'),
    InviteFont.google('lobster', 'Lobster', 'Display'),
    InviteFont.google('pacifico', 'Pacifico', 'Display'),
    InviteFont.google('bebas', 'Bebas Neue', 'Display'),
    InviteFont.google('anton', 'Anton', 'Display'),
    InviteFont.google('righteous', 'Righteous', 'Display'),
    InviteFont.google('fredoka', 'Fredoka', 'Display'),

    // Handwriting — the "signed by the host" register.
    InviteFont.google('dancing', 'Dancing Script', 'Handwriting'),
    InviteFont.google('greatvibes', 'Great Vibes', 'Handwriting'),
    InviteFont.google('sacramento', 'Sacramento', 'Handwriting'),
    InviteFont.google('caveat', 'Caveat', 'Handwriting'),
    InviteFont.google('satisfy', 'Satisfy', 'Handwriting'),
    InviteFont.google('parisienne', 'Parisienne', 'Handwriting'),

    // Serif — formal invitations.
    InviteFont.google('libre', 'Libre Baskerville', 'Serif'),
    InviteFont.google('lora', 'Lora', 'Serif'),
    InviteFont.google('crimson', 'Crimson Text', 'Serif'),
    InviteFont.google('eb', 'EB Garamond', 'Serif'),
    InviteFont.google('merriweather', 'Merriweather', 'Serif'),

    // Sans — dates, venues, the small print.
    InviteFont.google('poppins', 'Poppins', 'Sans'),
    InviteFont.google('raleway', 'Raleway', 'Sans'),
    InviteFont.google('inter', 'Inter', 'Sans'),
    InviteFont.google('nunito', 'Nunito', 'Sans'),
    InviteFont.google('quicksand', 'Quicksand', 'Sans'),
    InviteFont.google('oswald', 'Oswald', 'Sans'),
  ];

  static const fallback = montserrat;

  /// The groups in catalogue order, each with its faces.
  static List<({String group, List<InviteFont> fonts})> grouped() {
    final order = <String>[];
    final byGroup = <String, List<InviteFont>>{};
    for (final font in all) {
      if (!byGroup.containsKey(font.group)) order.add(font.group);
      byGroup.putIfAbsent(font.group, () => []).add(font);
    }
    return [for (final group in order) (group: group, fonts: byGroup[group]!)];
  }

  static InviteFont byKey(String? key) {
    for (final font in all) {
      if (font.key == key) return font;
    }
    return fallback;
  }
}

/// How a layer's lines sit against each other.
enum LayerAlign {
  left('left', TextAlign.left),
  center('center', TextAlign.center),
  right('right', TextAlign.right);

  const LayerAlign(this.wireValue, this.textAlign);

  final String wireValue;
  final TextAlign textAlign;

  static LayerAlign fromWire(String? value) => LayerAlign.values.firstWhere(
    (a) => a.wireValue == value,
    orElse: () => center,
  );
}

/// One piece of text the host placed on the card.
///
/// Every geometric value is a *fraction of the canvas*, never a logical pixel.
/// The editor draws at whatever width the phone gives it and the export draws
/// at [InviteDesign.exportWidth]; storing pixels would mean a card that looked
/// right while editing and came out wrong, by exactly the ratio between the
/// two.
@immutable
class TextLayer {
  const TextLayer({
    required this.id,
    required this.text,
    required this.dx,
    required this.dy,
    required this.fontSize,
    required this.widthFactor,
    required this.fontKey,
    required this.color,
    required this.bold,
    required this.italic,
    required this.align,
    required this.rotation,
  });

  /// A new layer, centred in the background's safe area.
  factory TextLayer.fresh({
    required String id,
    required String text,
    required Rect safeArea,
  }) => TextLayer(
    id: id,
    text: text,
    dx: safeArea.center.dx,
    dy: safeArea.center.dy,
    fontSize: defaultFontSize,
    widthFactor: math.min(0.8, safeArea.width),
    fontKey: InviteFonts.fallback.key,
    color: 0xFF1F1F1F,
    bold: true,
    italic: false,
    align: LayerAlign.center,
    rotation: 0,
  );

  final String id;
  final String text;

  /// The layer's centre, 0..1 across and down the canvas.
  final double dx;
  final double dy;

  /// Type size as a fraction of the canvas *width*, so a layer keeps its
  /// proportion whatever the card is rendered at.
  final double fontSize;

  /// How wide the text box is before it wraps, as a fraction of canvas width.
  final double widthFactor;

  final String fontKey;

  /// ARGB. The alpha channel carries the layer's opacity — one field rather
  /// than two, so a colour and an opacity can never disagree.
  final int color;

  final bool bold;
  final bool italic;
  final LayerAlign align;

  /// Turns, not radians: a quarter turn is 0.25, which is what the rotate
  /// handle and the snap-to-straight both work in.
  final double rotation;

  static const defaultFontSize = 0.09;
  static const minFontSize = 0.02;
  static const maxFontSize = 0.30;

  InviteFont get font => InviteFonts.byKey(fontKey);

  Color get displayColor => Color(color);

  double get opacity => (color >> 24 & 0xFF) / 0xFF;

  /// Same colour, new alpha. Used by the opacity slider.
  TextLayer withOpacity(double value) {
    final alpha = (value.clamp(0.0, 1.0) * 0xFF).round();
    return copyWith(color: (color & 0x00FFFFFF) | (alpha << 24));
  }

  /// Same alpha, new colour. Used by the swatches, so picking a colour does not
  /// silently reset an opacity the host already set.
  TextLayer withColor(Color value) =>
      copyWith(color: (color & 0xFF000000) | (value.toARGB32() & 0x00FFFFFF));

  TextLayer copyWith({
    String? text,
    double? dx,
    double? dy,
    double? fontSize,
    double? widthFactor,
    String? fontKey,
    int? color,
    bool? bold,
    bool? italic,
    LayerAlign? align,
    double? rotation,
  }) => TextLayer(
    id: id,
    text: text ?? this.text,
    // Clamped here rather than at every call site: a drag, a nudge and a
    // restored design all have to keep the layer on the card, and one of them
    // forgetting would put text where nobody can reach it to fix.
    dx: (dx ?? this.dx).clamp(0.0, 1.0),
    dy: (dy ?? this.dy).clamp(0.0, 1.0),
    fontSize: (fontSize ?? this.fontSize).clamp(minFontSize, maxFontSize),
    widthFactor: (widthFactor ?? this.widthFactor).clamp(0.1, 1.0),
    fontKey: fontKey ?? this.fontKey,
    color: color ?? this.color,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    align: align ?? this.align,
    rotation: rotation ?? this.rotation,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'dx': dx,
    'dy': dy,
    'fontSize': fontSize,
    'widthFactor': widthFactor,
    'font': fontKey,
    'color': color,
    'bold': bold,
    'italic': italic,
    'align': align.wireValue,
    'rotation': rotation,
  };

  factory TextLayer.fromJson(Map<String, dynamic> json) => TextLayer(
    id: json['id'] as String,
    text: json['text'] as String? ?? '',
    dx: (json['dx'] as num?)?.toDouble() ?? 0.5,
    dy: (json['dy'] as num?)?.toDouble() ?? 0.5,
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? defaultFontSize,
    widthFactor: (json['widthFactor'] as num?)?.toDouble() ?? 0.8,
    fontKey: json['font'] as String? ?? InviteFonts.fallback.key,
    color: (json['color'] as num?)?.toInt() ?? 0xFF1F1F1F,
    bold: json['bold'] as bool? ?? false,
    italic: json['italic'] as bool? ?? false,
    align: LayerAlign.fromWire(json['align'] as String?),
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is TextLayer &&
      other.id == id &&
      other.text == text &&
      other.dx == dx &&
      other.dy == dy &&
      other.fontSize == fontSize &&
      other.widthFactor == widthFactor &&
      other.fontKey == fontKey &&
      other.color == color &&
      other.bold == bold &&
      other.italic == italic &&
      other.align == align &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(
    id,
    text,
    dx,
    dy,
    fontSize,
    widthFactor,
    fontKey,
    color,
    bold,
    italic,
    align,
    rotation,
  );
}

/// What a layer in a layout stands for, and so which event fact fills it.
enum LayerRole {
  /// The small line above the headline — "You're invited", "Join us".
  eyebrow,

  /// The event's title.
  headline,

  /// When. Formatted on the device, in the phone's zone — the same choice
  /// `event_detail_screen` already makes for the same date.
  date,

  /// Where. Dropped entirely when the event has no venue: an invitation that
  /// says "Venue: null" is worse than one that says nothing.
  venue,

  /// "Hosted by …" — the signed-in user who created the event, never the
  /// event's `personName` (that is who the party is *for*). Omitted when the
  /// event is for the host themself: "Siya's 24th, hosted by Siya" says the
  /// same name twice.
  host,
}

/// Which of the background's two colours a layer is set in.
enum InkRole { ink, accent }

/// One line of a layout, described against the background's safe area.
///
/// Nothing here is a canvas coordinate. [y] is a fraction down the *safe
/// area* and the x is always its centre, so the same layout lands correctly
/// on a background whose safe area starts a quarter of the way down and on one
/// whose starts a third. Sizes are fractions of canvas width, as on
/// [TextLayer], so the card keeps its proportions at any render size.
@immutable
class LayoutLayer {
  const LayoutLayer({
    required this.role,
    required this.y,
    required this.fontKey,
    required this.size,
    this.ink = InkRole.ink,
    this.bold = false,
    this.italic = false,
    this.text,
    this.uppercase = false,
    this.widthFactor = 0.95,
  });

  final LayerRole role;
  final double y;
  final String fontKey;
  final double size;
  final InkRole ink;
  final bool bold;
  final bool italic;

  /// Fixed copy for an [LayerRole.eyebrow]; every other role reads from the
  /// event.
  final String? text;

  /// Small-caps register, done by transforming the text: [TextLayer] has no
  /// letter-spacing, and an uppercased sans at a small size is the same
  /// effect a guest reads.
  final bool uppercase;

  /// As a fraction of the safe area's width.
  final double widthFactor;
}

/// A named arrangement of lines — what the picker calls a "style".
///
/// This is the whole of what a template used to be, moved onto the designer:
/// a layout is applied to *any* background and pre-filled with the event's
/// own details, and the result is an ordinary editable design. The
/// server-rendered template it replaces could do neither.
@immutable
class InviteLayout {
  const InviteLayout({
    required this.key,
    required this.label,
    required this.layers,
    this.eventTypes = const [],
  });

  final String key;
  final String label;
  final List<LayoutLayer> layers;

  /// Which occasions offer this layout. Empty means every occasion.
  final List<EventType> eventTypes;

  bool offers(EventType type) =>
      eventTypes.isEmpty || eventTypes.contains(type);
}

/// The event facts a layout is filled from.
///
/// Nullable fields are *absent*, not empty: a layer whose fact is null is left
/// out of the design rather than rendered blank, so a host with no venue does
/// not get an empty box to delete.
@immutable
class InviteFacts {
  const InviteFacts({
    required this.title,
    required this.dateLine,
    this.venue,
    this.host,
  });

  /// What the picker shows before the event has loaded, and what a layout
  /// preview is rendered with when there is no event at all.
  static const placeholder = InviteFacts(
    title: 'Your Celebration',
    dateLine: 'Date & time',
    venue: 'Venue',
    host: 'Hosted by you',
  );

  final String title;
  final String dateLine;
  final String? venue;

  /// Already phrased — "Hosted by Rohan" — so the layout prints it as is.
  /// Null when there is nobody to name, or when the host is the one being
  /// celebrated.
  final String? host;

  String? forRole(LayerRole role) => switch (role) {
    LayerRole.eyebrow => null,
    LayerRole.headline => title,
    LayerRole.date => dateLine,
    LayerRole.venue => venue,
    LayerRole.host => host,
  };
}

/// Every layout the app ships.
///
/// Five, deliberately distinct in register rather than in colour — colour is
/// the background's job. Each is a different answer to "what kind of party":
/// formal, loud, handwritten, plain, fun.
abstract final class InviteLayouts {
  /// Serif headline under a tracked eyebrow. The wedding-stationery register.
  static const classic = InviteLayout(
    key: 'classic',
    label: 'Classic',
    layers: [
      LayoutLayer(
        role: LayerRole.eyebrow,
        text: "You're invited",
        y: 0.12,
        fontKey: 'raleway',
        size: 0.036,
        uppercase: true,
        ink: InkRole.accent,
      ),
      LayoutLayer(
        role: LayerRole.headline,
        y: 0.36,
        fontKey: 'playfair',
        size: 0.11,
        bold: true,
      ),
      LayoutLayer(
        role: LayerRole.date,
        y: 0.66,
        fontKey: 'raleway',
        size: 0.042,
      ),
      LayoutLayer(
        role: LayerRole.venue,
        y: 0.78,
        fontKey: 'raleway',
        size: 0.038,
      ),
      LayoutLayer(
        role: LayerRole.host,
        y: 0.92,
        fontKey: 'raleway',
        size: 0.032,
        italic: true,
        ink: InkRole.accent,
      ),
    ],
  );

  /// One enormous condensed headline. For the party that is the point.
  static const bold = InviteLayout(
    key: 'bold',
    label: 'Bold',
    layers: [
      LayoutLayer(
        role: LayerRole.headline,
        y: 0.32,
        fontKey: 'bebas',
        size: 0.19,
        uppercase: true,
        widthFactor: 1.0,
      ),
      LayoutLayer(
        role: LayerRole.date,
        y: 0.66,
        fontKey: 'oswald',
        size: 0.05,
        ink: InkRole.accent,
        uppercase: true,
      ),
      LayoutLayer(
        role: LayerRole.venue,
        y: 0.80,
        fontKey: 'oswald',
        size: 0.04,
      ),
    ],
  );

  /// Handwritten headline — the note-from-the-host register.
  static const script = InviteLayout(
    key: 'script',
    label: 'Script',
    layers: [
      LayoutLayer(
        role: LayerRole.eyebrow,
        text: 'Join us to celebrate',
        y: 0.14,
        fontKey: 'lora',
        size: 0.04,
        italic: true,
      ),
      LayoutLayer(
        role: LayerRole.headline,
        y: 0.40,
        fontKey: 'greatvibes',
        size: 0.15,
        ink: InkRole.accent,
      ),
      LayoutLayer(role: LayerRole.date, y: 0.68, fontKey: 'lora', size: 0.042),
      LayoutLayer(role: LayerRole.venue, y: 0.80, fontKey: 'lora', size: 0.038),
      LayoutLayer(
        role: LayerRole.host,
        y: 0.93,
        fontKey: 'lora',
        size: 0.032,
        italic: true,
      ),
    ],
  );

  /// Clean sans throughout. The one that gets out of the artwork's way.
  static const modern = InviteLayout(
    key: 'modern',
    label: 'Modern',
    layers: [
      LayoutLayer(
        role: LayerRole.headline,
        y: 0.30,
        fontKey: 'poppins',
        size: 0.10,
        bold: true,
      ),
      LayoutLayer(
        role: LayerRole.date,
        y: 0.58,
        fontKey: 'poppins',
        size: 0.046,
        ink: InkRole.accent,
        bold: true,
      ),
      LayoutLayer(
        role: LayerRole.venue,
        y: 0.72,
        fontKey: 'poppins',
        size: 0.038,
      ),
      LayoutLayer(
        role: LayerRole.host,
        y: 0.90,
        fontKey: 'poppins',
        size: 0.032,
      ),
    ],
  );

  /// Rounded and loud. Birthdays only — it is wrong for an anniversary.
  static const playful = InviteLayout(
    key: 'playful',
    label: 'Playful',
    eventTypes: [EventType.birthday],
    layers: [
      LayoutLayer(
        role: LayerRole.eyebrow,
        text: "Let's celebrate!",
        y: 0.12,
        fontKey: 'fredoka',
        size: 0.05,
        ink: InkRole.accent,
        bold: true,
      ),
      LayoutLayer(
        role: LayerRole.headline,
        y: 0.40,
        fontKey: 'fredoka',
        size: 0.12,
        bold: true,
      ),
      LayoutLayer(
        role: LayerRole.date,
        y: 0.68,
        fontKey: 'nunito',
        size: 0.044,
        bold: true,
      ),
      LayoutLayer(
        role: LayerRole.venue,
        y: 0.82,
        fontKey: 'nunito',
        size: 0.038,
      ),
    ],
  );

  static const all = <InviteLayout>[classic, bold, script, modern, playful];

  static InviteLayout? byKey(String? key) {
    if (key == null) return null;
    for (final layout in all) {
      if (layout.key == key) return layout;
    }
    return null;
  }

  static List<InviteLayout> forType(EventType? type) =>
      type == null ? all : all.where((l) => l.offers(type)).toList();
}

/// A whole invitation: one fixed background and the text on top of it.
@immutable
class InviteDesign {
  const InviteDesign({required this.backgroundKey, required this.layers});

  const InviteDesign.empty(this.backgroundKey) : layers = const [];

  /// A layout applied to a background and filled with the event's details.
  ///
  /// The result is an ordinary design: every line is a [TextLayer] the host
  /// can drag, restyle or delete, which is the whole point of doing this on
  /// the canvas rather than on the server.
  ///
  /// Layer ids carry the `tpl_` prefix on purpose. The designer's controller
  /// numbers the layers *it* creates `layer_0`, `layer_1`… from zero and does
  /// not look at what it was given, so seeding with that scheme would have the
  /// first added line share an id with a pre-placed one.
  factory InviteDesign.fromLayout({
    required InviteBackground background,
    required InviteLayout layout,
    required InviteFacts facts,
  }) {
    final area = background.safeArea;
    final layers = <TextLayer>[];

    for (final spec in layout.layers) {
      final raw = spec.text ?? facts.forRole(spec.role);
      // A fact the event does not have is left out, not printed blank.
      if (raw == null || raw.trim().isEmpty) continue;

      layers.add(
        TextLayer(
          id: 'tpl_${spec.role.name}',
          text: spec.uppercase ? raw.toUpperCase() : raw,
          dx: area.center.dx,
          dy: area.top + spec.y * area.height,
          fontSize: spec.size,
          widthFactor: area.width * spec.widthFactor,
          fontKey: spec.fontKey,
          color: switch (spec.ink) {
            InkRole.ink => background.ink,
            InkRole.accent => background.accent,
          },
          bold: spec.bold,
          italic: spec.italic,
          align: LayerAlign.center,
          rotation: 0,
        ),
      );
    }

    return InviteDesign(backgroundKey: background.key, layers: layers);
  }

  final String backgroundKey;
  final List<TextLayer> layers;

  /// 9:16 — the shape the user chose, and what `happy_birthday_bg` already is
  /// at 1200×2133.
  static const aspectRatio = 9 / 16;

  /// What the card exports at. 1080 wide keeps the taller background close to
  /// its native resolution without producing a file too big for the 10 MB
  /// `event_invite` cap.
  static const exportWidth = 1080.0;
  static const exportHeight = exportWidth / aspectRatio;

  InviteBackground? get background => InviteBackgrounds.byKey(backgroundKey);

  bool get isEmpty => layers.isEmpty;

  InviteDesign copyWith({String? backgroundKey, List<TextLayer>? layers}) =>
      InviteDesign(
        backgroundKey: backgroundKey ?? this.backgroundKey,
        layers: layers ?? this.layers,
      );

  Map<String, dynamic> toJson() => {
    'background': backgroundKey,
    'layers': layers.map((l) => l.toJson()).toList(),
  };

  factory InviteDesign.fromJson(Map<String, dynamic> json) => InviteDesign(
    backgroundKey: json['background'] as String? ?? '',
    layers:
        (json['layers'] as List<dynamic>?)
            ?.map((e) => TextLayer.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  @override
  bool operator ==(Object other) =>
      other is InviteDesign &&
      other.backgroundKey == backgroundKey &&
      listEquals(other.layers, layers);

  @override
  int get hashCode => Object.hash(backgroundKey, Object.hashAll(layers));
}
