import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/core/theme/app_colors.dart';
import 'package:wishtick_flutter/core/theme/app_dimens.dart';
import 'package:wishtick_flutter/core/theme/theme_controller.dart';
import 'package:wishtick_flutter/core/widgets/sparkle_icon.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/onboarding/domain/onboarding_options.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/colors_screen.dart';

import '../../helpers/onboarding_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TaxonomyOption colorOption(
    String key,
    String label,
    String group,
    String groupLabel,
  ) => TaxonomyOption(
    key: key,
    label: label,
    meta: {'hex': '#000000', 'group': group, 'groupLabel': groupLabel},
  );

  /// Matches the real seed's group keys (`taxonomy.seed.ts`) rather than the
  /// shared fixture's compact 'purple'/'green' groups — the icon lookup is
  /// keyed off these exact strings.
  final options = OnboardingOptions(
    interestCategories: const [],
    interests: const [],
    colors: [
      colorOption('white', 'White', 'neutral', 'Neutrals & Slate'),
      colorOption('cocoa', 'Cocoa', 'earth', 'Earth Tones'),
      colorOption('blush', 'Blush', 'pastel', 'Pastels'),
      colorOption('navy', 'Navy', 'blue', 'Blues'),
      // An unrecognised group — the icon lookup must fall back to no icon
      // rather than crashing on a missing asset.
      colorOption('mystery', 'Mystery', 'other', 'Other'),
    ],
    clothingSizes: const [],
    shoeSizes: const [],
    fitPreferences: const [],
    occasions: const [],
  );

  Future<void> pumpColors(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      ThemeModeController.prefsKey: 'light',
    });
    final prefs = await SharedPreferences.getInstance();

    tester.view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          onboardingRepositoryProvider.overrideWithValue(
            FakeOnboardingRepository(options: options),
          ),
        ],
        child: const MaterialApp(home: ColorsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The Image directly preceding a group's heading text, if the group has a
  /// matching icon.
  Image? iconBefore(WidgetTester tester, String label) {
    final row = tester.widget<Row>(
      find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
    );
    final images = row.children.whereType<Image>();
    return images.isEmpty ? null : images.single;
  }

  group('colour group headings', () {
    for (final MapEntry(key: label, value: asset) in {
      'Neutrals & Slate': 'assets/icons/Neutrals_Slate.png',
      'Earth Tones': 'assets/icons/Earth_Tones.png',
      'Pastels': 'assets/icons/Pastels.png',
      'Blues': 'assets/icons/Blues.png',
    }.entries) {
      testWidgets('$label gets its matching leading icon', (tester) async {
        await pumpColors(tester);

        final icon = iconBefore(tester, label);
        expect(icon, isNotNull, reason: '$label is missing a leading icon');
        expect((icon!.image as AssetImage).assetName, asset);
        expect(icon.width, AppSizes.iconLg);
        expect(icon.height, AppSizes.iconLg);
      });
    }

    testWidgets('an unrecognised group renders with no icon, not a crash', (
      tester,
    ) async {
      await pumpColors(tester);

      expect(find.text('Other'), findsOneWidget);
      expect(iconBefore(tester, 'Other'), isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('personalise note', () {
    testWidgets('uses the amber note tokens, not the gold celebration ones', (
      tester,
    ) async {
      await pumpColors(tester);

      final noteText = find.textContaining('This colors will be used');
      final card = tester.widget<Container>(
        find.ancestor(of: noteText, matching: find.byType(Container)).first,
      );
      expect(
        (card.decoration! as BoxDecoration).color,
        WishtickColors.light.noteSubtle,
      );

      final icon = tester.widget<SparkleIcon>(find.byType(SparkleIcon));
      expect(icon.color, WishtickColors.light.onNoteSubtle);

      final text = tester.widget<Text>(noteText);
      expect(text.style?.color, WishtickColors.light.onNoteSubtle);
    });

    testWidgets(
      'centres the icon against the text block, not just its first line',
      (tester) async {
        await pumpColors(tester);

        final row = tester.widget<Row>(
          find
              .ancestor(
                of: find.byType(SparkleIcon),
                matching: find.byType(Row),
              )
              .first,
        );
        expect(row.crossAxisAlignment, CrossAxisAlignment.center);
      },
    );
  });
}
