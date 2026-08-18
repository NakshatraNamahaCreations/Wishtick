import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/onboarding/domain/onboarding_options.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/size_fit_screen.dart';

import '../../helpers/onboarding_fakes.dart';

/// Pumps [SizeFitScreen] on its own — no router, no session — because nothing
/// under test taps back or skip. `OnboardingStepScaffold` only reaches for
/// `GoRouter` if those callbacks fire, so a bare [MaterialApp] is enough.
Future<void> pumpSizeFit(
  WidgetTester tester, {
  OnboardingRepository? repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(
          repository ?? FakeOnboardingRepository(),
        ),
      ],
      child: const MaterialApp(home: SizeFitScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// The icon's own [SizedBox], found by the label of the tile that carries it.
///
/// Not `find.ancestor` — the SizedBox is a *sibling* of the label inside
/// their shared tile Container, not its ancestor — so this locates the tile
/// the way [assetFor] does, then descends into it.
Size iconSizeFor(WidgetTester tester, String label) => tester.getSize(
  find
      .descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
        matching: find.byType(SizedBox),
      )
      .first,
);

/// A clothing list long enough to check the *middle* of the size ramp, not
/// just its two ends. [FakeOnboardingRepository]'s own catalogue only carries
/// two clothing sizes — plenty to prove first differs from last, not enough
/// to prove the run between them is a ramp rather than a two-step toggle.
class _WideClothingRepository extends FakeOnboardingRepository {
  @override
  Future<OnboardingOptions> options() async {
    final base = await super.options();
    return OnboardingOptions(
      interestCategories: base.interestCategories,
      interests: base.interests,
      colors: base.colors,
      clothingSizes: const [
        TaxonomyOption(key: 'xxs', label: 'XXS'),
        TaxonomyOption(key: 's', label: 'S'),
        TaxonomyOption(key: 'l', label: 'L'),
        TaxonomyOption(key: 'xxxl', label: '3XL'),
      ],
      shoeSizes: base.shoeSizes,
      fitPreferences: base.fitPreferences,
      occasions: base.occasions,
    );
  }
}

/// The tile's own filled box, found by the label it wraps.
BoxDecoration decorationFor(WidgetTester tester, String label) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

/// The asset path backing the artwork drawn inside the tile labelled [label].
String assetFor(WidgetTester tester, String label) {
  final image = tester.widget<Image>(
    find
        .descendant(
          of: find
              .ancestor(of: find.text(label), matching: find.byType(Container))
              .first,
          matching: find.byType(Image),
        )
        .first,
  );
  return (image.image as AssetImage).assetName;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // TileIcons has no widget dependency, so its path resolution is checked
  // directly rather than by hunting for an Image in a rendered tree.
  group('TileIcons', () {
    test('clothing and shoes swap the whole file on selection, not a tint', () {
      expect(
        (TileIcons.fixed('clothing', false) as Image).image,
        const AssetImage('assets/icons/clothing.png'),
      );
      expect(
        (TileIcons.fixed('clothing', true) as Image).image,
        const AssetImage('assets/icons/clothing_w.png'),
      );
      expect(
        (TileIcons.fixed('shoes', false) as Image).image,
        const AssetImage('assets/icons/shoes.png'),
      );
      expect(
        (TileIcons.fixed('shoes', true) as Image).image,
        const AssetImage('assets/icons/shoes_w.png'),
      );
    });

    test('every fit key resolves to its own asset, capitalisation and all', () {
      // The four files on disk are inconsistently cased (Slim.png,
      // regular.png, Relaxed.png, Oversized.png) — this pins the exact
      // mapping so a careless rename silently breaks nothing.
      const expected = {
        'slim': 'Slim',
        'regular': 'regular',
        'relaxed': 'Relaxed',
        'oversized': 'Oversized',
      };
      for (final entry in expected.entries) {
        expect(
          (TileIcons.fit(entry.key, false) as Image).image,
          AssetImage('assets/icons/${entry.value}.png'),
          reason: entry.key,
        );
        expect(
          (TileIcons.fit(entry.key, true) as Image).image,
          AssetImage('assets/icons/${entry.value}_w.png'),
          reason: '${entry.key} selected',
        );
      }
    });

    test('an unrecognised fit key falls back to the clothing glyph', () {
      // The catalogue comes from a live API; a fit the client adds tomorrow
      // must not crash the screen before an asset exists for it.
      expect(
        (TileIcons.fit('petite', false) as Image).image,
        const AssetImage('assets/icons/clothing.png'),
      );
    });
  });

  group('SizeFitScreen tiles', () {
    testWidgets('clothing options all show the same clothing artwork', (
      tester,
    ) async {
      await pumpSizeFit(tester);

      // The fake catalogue's two clothing sizes (XS, M) — see buildOptions().
      expect(assetFor(tester, 'XS'), 'assets/icons/clothing.png');
      expect(assetFor(tester, 'M'), 'assets/icons/clothing.png');
    });

    testWidgets('shoe options all show the same shoe artwork', (tester) async {
      await pumpSizeFit(tester);

      // Only the UK size is on screen by default — see buildOptions() and the
      // UK/US/EU toggle's default.
      expect(assetFor(tester, '9'), 'assets/icons/shoes.png');
    });

    testWidgets('fit options each show their own artwork', (tester) async {
      await pumpSizeFit(tester);

      expect(assetFor(tester, 'Regular'), 'assets/icons/regular.png');
      expect(assetFor(tester, 'Slim'), 'assets/icons/Slim.png');
    });

    testWidgets('selecting a tile swaps to the white asset, not a tint', (
      tester,
    ) async {
      await pumpSizeFit(tester);

      await tester.tap(find.text('XS'));
      await tester.pumpAndSettle();

      expect(assetFor(tester, 'XS'), 'assets/icons/clothing_w.png');
      expect(assetFor(tester, 'M'), 'assets/icons/clothing.png');
      expect(decorationFor(tester, 'XS').color, isNotNull);
    });

    testWidgets(
      'the fit-preference icon is larger than the clothing icon, and both '
      'scale with their tile',
      (tester) async {
        await pumpSizeFit(tester);

        final clothingIcon = iconSizeFor(tester, 'XS');
        final fitIcon = iconSizeFor(tester, 'Regular');

        // Fit-preference tiles are the `large` tiles; their icon must read as
        // bigger, not merely the same fixed constant stretched into a bigger
        // box.
        expect(fitIcon.width, greaterThan(clothingIcon.width));

        // Both stay square — BoxFit.contain has room to do its job without
        // the tile forcing a stretch.
        expect(clothingIcon.width, clothingIcon.height);
        expect(fitIcon.width, fitIcon.height);
      },
    );

    testWidgets('the clothing icon itself grows from the smallest size to the '
        'largest, not just the label beneath it', (tester) async {
      await pumpSizeFit(tester);

      // FakeOnboardingRepository's catalogue is exactly [XS, M] — first and
      // last of a two-rung ramp.
      final xs = iconSizeFor(tester, 'XS');
      final m = iconSizeFor(tester, 'M');

      expect(
        m.width,
        greaterThan(xs.width),
        reason:
            'M should read larger than XS, not identical apart from '
            'the label',
      );
    });

    testWidgets('the ramp runs smoothly through the middle sizes too, not '
        'just first-vs-last', (tester) async {
      await pumpSizeFit(tester, repository: _WideClothingRepository());

      final sizes = [
        'XXS',
        'S',
        'L',
        '3XL',
      ].map((label) => iconSizeFor(tester, label).width).toList();

      // Strictly increasing end to end — a first/last-only toggle would tie
      // the two middle sizes together instead of spacing all four out.
      for (var i = 1; i < sizes.length; i++) {
        expect(
          sizes[i],
          greaterThan(sizes[i - 1]),
          reason: 'size $i should read larger than size ${i - 1}: $sizes',
        );
      }
    });

    testWidgets(
      'fit-preference icons stay the same size regardless of list order',
      (tester) async {
        await pumpSizeFit(tester);

        // The fake lists Regular before Slim — if rank-scaling had leaked
        // into this section, Slim would render smaller than Regular, which
        // is backwards from what the artwork itself implies (Slim, if
        // anything, should look slim — not literally shrink the icon box).
        final regular = iconSizeFor(tester, 'Regular');
        final slim = iconSizeFor(tester, 'Slim');

        expect(slim, regular);
      },
    );
  });
}
