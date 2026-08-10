import 'package:flutter/foundation.dart';

/// One selectable taxonomy term from `GET /onboarding/options`.
@immutable
class TaxonomyOption {
  const TaxonomyOption({required this.key, required this.label, this.meta});

  final String key;
  final String label;
  final Map<String, String>? meta;

  factory TaxonomyOption.fromJson(Map<String, dynamic> json) => TaxonomyOption(
    key: json['key'] as String,
    label: json['label'] as String,
    meta: (json['meta'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, v.toString()),
    ),
  );
}

/// One colour-group section on the colours screen (Figma `39:1061`).
@immutable
class ColorGroup {
  const ColorGroup({
    required this.group,
    required this.label,
    required this.colors,
  });

  final String group;
  final String label;
  final List<TaxonomyOption> colors;
}

/// Everything the onboarding screens select from, server-defined.
@immutable
class OnboardingOptions {
  const OnboardingOptions({
    required this.interestCategories,
    required this.interests,
    required this.colors,
    required this.clothingSizes,
    required this.shoeSizes,
    required this.fitPreferences,
    required this.occasions,
    this.relations = const [],
  });

  final List<TaxonomyOption> interestCategories;
  final List<TaxonomyOption> interests;
  final List<TaxonomyOption> colors;
  final List<TaxonomyOption> clothingSizes;
  final List<TaxonomyOption> shoeSizes;
  final List<TaxonomyOption> fitPreferences;
  final List<TaxonomyOption> occasions;

  /// Who someone is to you, grouped for the picker on `2252:423`.
  final List<TaxonomyOption> relations;

  /// Granular interests belonging to one category, in server order.
  List<TaxonomyOption> interestsFor(String categoryKey) =>
      interests.where((o) => o.meta?['category'] == categoryKey).toList();

  /// Colours grouped into their sections, preserving server order.
  List<ColorGroup> get colorGroups {
    final groups = <String, ColorGroup>{};
    for (final colour in colors) {
      final group = colour.meta?['group'] ?? 'other';
      final label = colour.meta?['groupLabel'] ?? 'Colours';
      groups
          .putIfAbsent(
            group,
            () => ColorGroup(group: group, label: label, colors: []),
          )
          .colors
          .add(colour);
    }
    return groups.values.toList();
  }

  /// Shoe sizes for one sizing system (`uk` | `us` | `eu`).
  /// Relations grouped for the collapsible picker (`2252:423`), in seed order.
  ///
  /// Same shape as [colorGroups] — the server carries `meta.group` and
  /// `meta.groupLabel` so a new group is a seed edit, not an app release.
  List<RelationGroup> get relationGroups {
    final groups = <String, RelationGroup>{};
    for (final relation in relations) {
      final group = relation.meta?['group'] ?? 'other';
      final label = relation.meta?['groupLabel'] ?? 'Other';
      groups
          .putIfAbsent(
            group,
            () => RelationGroup(group: group, label: label, relations: []),
          )
          .relations
          .add(relation);
    }
    return groups.values.toList();
  }

  List<TaxonomyOption> shoeSizesFor(String system) =>
      shoeSizes.where((o) => o.meta?['system'] == system).toList();

  static List<TaxonomyOption> _list(
    Map<String, dynamic> options,
    String kind,
  ) => (options[kind] as List<dynamic>? ?? const [])
      .map((e) => TaxonomyOption.fromJson(e as Map<String, dynamic>))
      .toList();

  factory OnboardingOptions.fromJson(Map<String, dynamic> json) {
    final options = json['options'] as Map<String, dynamic>? ?? const {};
    return OnboardingOptions(
      interestCategories: _list(options, 'interest_category'),
      interests: _list(options, 'interest'),
      colors: _list(options, 'color'),
      clothingSizes: _list(options, 'clothing_size'),
      shoeSizes: _list(options, 'shoe_size'),
      fitPreferences: _list(options, 'fit_preference'),
      occasions: _list(options, 'occasion'),
      relations: _list(options, 'relation'),
    );
  }
}

/// One saved entry from "Never Miss a Celebration" (Figma `199:10`).
@immutable
class ImportantDate {
  const ImportantDate({
    required this.id,
    required this.personName,
    required this.relation,
    required this.occasionKey,
    required this.date,
  });

  final String id;
  final String personName;
  final String relation;
  final String occasionKey;

  /// Date-only ISO string (`1999-07-17`).
  final String date;

  factory ImportantDate.fromJson(Map<String, dynamic> json) => ImportantDate(
    id: json['id'] as String,
    personName: json['personName'] as String,
    relation: json['relation'] as String,
    occasionKey: json['occasionKey'] as String,
    date: json['date'] as String,
  );
}

/// One collapsible section of the relation picker (`2252:423`).
@immutable
class RelationGroup {
  const RelationGroup({
    required this.group,
    required this.label,
    required this.relations,
  });

  final String group;
  final String label;
  final List<TaxonomyOption> relations;
}
