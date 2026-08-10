import 'package:flutter/foundation.dart';

import 'event.dart';

/// One editable text field on a template — "Hosted by", "Venue", and so on.
@immutable
class TemplateSlot {
  const TemplateSlot({
    required this.key,
    required this.label,
    required this.placeholder,
    required this.maxLength,
    required this.required,
  });

  final String key;
  final String label;
  final String placeholder;
  final int maxLength;
  final bool required;

  factory TemplateSlot.fromJson(Map<String, dynamic> json) => TemplateSlot(
    key: json['key'] as String,
    label: json['label'] as String? ?? '',
    placeholder: json['placeholder'] as String? ?? '',
    maxLength: json['maxLength'] as int? ?? 80,
    required: json['required'] as bool? ?? false,
  );
}

/// A colourway for a template.
///
/// Kept as `#RRGGBB` strings rather than parsed here: these are the
/// *template's* palette, not the app's, and they must not shift when the app
/// theme does. Widgets turn them into colours with `parseHexColor`, which
/// needs a themed fallback the domain has no business knowing about.
@immutable
class TemplateColorVariant {
  const TemplateColorVariant({
    required this.key,
    required this.label,
    required this.background,
    required this.accent,
    required this.text,
    required this.muted,
  });

  final String key;
  final String label;
  final String background;
  final String accent;
  final String text;
  final String muted;

  factory TemplateColorVariant.fromJson(Map<String, dynamic> json) =>
      TemplateColorVariant(
        key: json['key'] as String,
        label: json['label'] as String? ?? '',
        background: json['background'] as String? ?? '#FFFFFF',
        accent: json['accent'] as String? ?? '#000000',
        text: json['text'] as String? ?? '#000000',
        muted: json['muted'] as String? ?? '#666666',
      );
}

/// An invitation design (`263:900`).
@immutable
class InviteTemplate {
  const InviteTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.eventTypes,
    required this.slots,
    required this.variants,
  });

  final String id;
  final String name;
  final String description;

  /// Which occasions this design is offered for.
  final List<EventType> eventTypes;

  final List<TemplateSlot> slots;
  final List<TemplateColorVariant> variants;

  factory InviteTemplate.fromJson(Map<String, dynamic> json) => InviteTemplate(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    eventTypes:
        (json['eventTypes'] as List<dynamic>?)
            ?.map((e) => EventType.fromWire(e as String))
            .toList() ??
        const [],
    slots:
        (json['slots'] as List<dynamic>?)
            ?.map((e) => TemplateSlot.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    variants:
        (json['variants'] as List<dynamic>?)
            ?.map(
              (e) => TemplateColorVariant.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        const [],
  );
}

/// The card as it will actually be drawn — slot values after defaults and
/// truncation, plus the palette, so a client can render it natively instead of
/// waiting on the rasterised image.
@immutable
class InviteCardContent {
  const InviteCardContent({
    required this.headline,
    required this.dateLine,
    this.subtitle,
    this.hostLine,
    this.venue,
    this.note,
  });

  final String headline;
  final String? subtitle;
  final String? hostLine;
  final String? venue;
  final String? note;

  /// Already formatted in the event's own timezone by the server — never
  /// re-derived here, or a phone in a different zone would print a different
  /// date on the same invitation.
  final String dateLine;

  factory InviteCardContent.fromJson(Map<String, dynamic> json) =>
      InviteCardContent(
        headline: json['headline'] as String? ?? '',
        subtitle: json['subtitle'] as String?,
        hostLine: json['hostLine'] as String?,
        venue: json['venue'] as String?,
        note: json['note'] as String?,
        dateLine: json['dateLine'] as String? ?? '',
      );
}

/// What the invitation designer previews (`263:900`).
@immutable
class InvitePreview {
  const InvitePreview({
    required this.templateId,
    required this.colorVariant,
    required this.palette,
    required this.resolved,
    this.imageUrl,
  });

  final String templateId;
  final String colorVariant;
  final TemplateColorVariant palette;
  final InviteCardContent resolved;

  /// The rasterised card. Null while it is still being generated — the native
  /// render from [palette] and [resolved] is what the designer shows meanwhile.
  final String? imageUrl;

  factory InvitePreview.fromJson(Map<String, dynamic> json) => InvitePreview(
    templateId: json['templateId'] as String? ?? '',
    colorVariant: json['colorVariant'] as String? ?? '',
    palette: TemplateColorVariant.fromJson(
      json['palette'] as Map<String, dynamic>? ?? const {'key': ''},
    ),
    resolved: InviteCardContent.fromJson(
      json['resolved'] as Map<String, dynamic>? ?? const {},
    ),
    imageUrl: json['imageUrl'] as String?,
  );
}
