import 'package:flutter/foundation.dart';

import '../../wishlist/domain/product.dart';

/// Why a shelf is on the feed — mirrors the backend's `DiscoverSectionKind`.
enum DiscoverSectionKind {
  /// Curated for one saved person's approaching occasion.
  personOccasion('person_occasion'),

  /// Everything under a price ceiling — "Gifts Under ₹2000".
  priceBand('price_band'),

  /// The top of the catalogue by price.
  premium('premium');

  const DiscoverSectionKind(this.wireValue);

  final String wireValue;

  static DiscoverSectionKind fromWire(String? value) => DiscoverSectionKind
      .values
      .firstWhere((v) => v.wireValue == value, orElse: () => priceBand);
}

/// Who a [DiscoverSectionKind.personOccasion] shelf is for.
@immutable
class DiscoverPerson {
  const DiscoverPerson({
    required this.importantDateId,
    required this.name,
    required this.relation,
    required this.occasionKey,
    required this.occasionLabel,
    required this.nextOccurrence,
    required this.daysAway,
  });

  final String importantDateId;
  final String name;
  final String relation;
  final String occasionKey;
  final String occasionLabel;
  final DateTime nextOccurrence;
  final int daysAway;

  factory DiscoverPerson.fromJson(Map<String, dynamic> json) => DiscoverPerson(
    importantDateId: json['importantDateId'] as String,
    name: json['name'] as String,
    relation: json['relation'] as String,
    occasionKey: json['occasionKey'] as String,
    occasionLabel: json['occasionLabel'] as String,
    nextOccurrence: DateTime.parse(json['nextOccurrence'] as String),
    daysAway: json['daysAway'] as int? ?? 0,
  );
}

/// The `products/search` filter that produced a shelf — handed to "Explore
/// More" verbatim so the client never re-derives the curation rules.
@immutable
class DiscoverExploreQuery {
  const DiscoverExploreQuery({
    required this.category,
    required this.minPriceMinor,
    required this.maxPriceMinor,
  });

  final String? category;
  final int? minPriceMinor;
  final int? maxPriceMinor;

  factory DiscoverExploreQuery.fromJson(Map<String, dynamic> json) =>
      DiscoverExploreQuery(
        category: json['category'] as String?,
        minPriceMinor: json['minPriceMinor'] as int?,
        maxPriceMinor: json['maxPriceMinor'] as int?,
      );
}

/// One shelf on the Discover feed.
@immutable
class DiscoverSection {
  const DiscoverSection({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.person,
    required this.items,
    required this.exploreQuery,
  });

  final DiscoverSectionKind kind;

  /// Ready to render — the backend composes "Gift suggestions for Siya's
  /// Birthday" so the possessive and the occasion label stay server-side.
  final String title;
  final String? subtitle;

  /// Set only on [DiscoverSectionKind.personOccasion].
  final DiscoverPerson? person;

  final List<NormalizedProduct> items;
  final DiscoverExploreQuery exploreQuery;

  factory DiscoverSection.fromJson(Map<String, dynamic> json) =>
      DiscoverSection(
        kind: DiscoverSectionKind.fromWire(json['kind'] as String?),
        title: json['title'] as String,
        subtitle: json['subtitle'] as String?,
        person: json['person'] == null
            ? null
            : DiscoverPerson.fromJson(json['person'] as Map<String, dynamic>),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => NormalizedProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
        exploreQuery: DiscoverExploreQuery.fromJson(
          json['exploreQuery'] as Map<String, dynamic>? ?? const {},
        ),
      );
}

/// `GET /discover/feed` — shelves already in display order.
@immutable
class DiscoverFeed {
  const DiscoverFeed({required this.sections});

  final List<DiscoverSection> sections;

  bool get isEmpty => sections.isEmpty;

  factory DiscoverFeed.fromJson(Map<String, dynamic> json) => DiscoverFeed(
    sections: (json['sections'] as List<dynamic>? ?? const [])
        .map((e) => DiscoverSection.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
