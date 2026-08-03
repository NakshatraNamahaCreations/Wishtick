import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/onboarding_flow_controller.dart';

import '../../helpers/onboarding_fakes.dart';

void main() {
  ({ProviderContainer container, FakeOnboardingRepository repo}) build() {
    final repo = FakeOnboardingRepository();
    final container = ProviderContainer(
      overrides: [onboardingRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return (container: container, repo: repo);
  }

  OnboardingFlowController controllerOf(ProviderContainer c) =>
      c.read(onboardingFlowProvider.notifier);
  OnboardingFlowState stateOf(ProviderContainer c) =>
      c.read(onboardingFlowProvider);

  group('options', () {
    test('loads once and reuses the result', () async {
      final t = build();
      await controllerOf(t.container).ensureOptions();
      await controllerOf(t.container).ensureOptions();

      expect(t.repo.optionsCalls, 1);
      expect(stateOf(t.container).options, isNotNull);
    });

    test('surfaces a load failure and can retry', () async {
      final t = build()
        ..repo.optionsFailure = const ApiException(
          code: ApiException.codeNetwork,
          message: 'down',
        );
      await controllerOf(t.container).ensureOptions();
      expect(stateOf(t.container).optionsError, isNotNull);

      t.repo.optionsFailure = null;
      await controllerOf(t.container).retryOptions();
      expect(stateOf(t.container).options, isNotNull);
      expect(stateOf(t.container).optionsError, isNull);
    });
  });

  group('interest selection', () {
    test('caps categories and preserves selection order', () {
      final t = build();
      final c = controllerOf(t.container);

      c.toggleCategory('fashion');
      c.toggleCategory('technology');
      // Third pick is ignored at the cap of 2.
      c.toggleCategory('other');

      expect(stateOf(t.container).selectedCategories, [
        'fashion',
        'technology',
      ]);
    });

    test('deselecting a category drops its granular picks', () {
      final t = build();
      final c = controllerOf(t.container);
      c.toggleCategory('fashion');
      c.toggleInterest('fashion', 'fashion_shoes');

      c.toggleCategory('fashion');

      expect(stateOf(t.container).selectedInterests['fashion'], isNull);
      expect(stateOf(t.container).allInterests, isEmpty);
    });

    test('caps granular picks per category', () {
      final t = build();
      final c = controllerOf(t.container);
      c.toggleCategory('fashion');

      c.toggleInterest('fashion', 'fashion_shoes');
      c.toggleInterest('fashion', 'fashion_watches');
      c.toggleInterest('fashion', 'fashion_bags');

      expect(stateOf(t.container).selectedInterests['fashion'], [
        'fashion_shoes',
        'fashion_watches',
      ]);
    });

    test('custom interests trim, dedupe, and cap length', () {
      final t = build();
      final c = controllerOf(t.container);

      c.addCustomInterest('  Astronomy ');
      c.addCustomInterest('Astronomy');
      c.addCustomInterest('x' * 41);

      expect(stateOf(t.container).customInterests, ['Astronomy']);
    });

    test('saveInterests sends everything collected', () async {
      final t = build();
      final c = controllerOf(t.container);
      c.toggleCategory('fashion');
      c.toggleInterest('fashion', 'fashion_shoes');
      c.addCustomInterest('Anime');

      final ok = await c.saveInterests();

      expect(ok, isTrue);
      // Field-by-field: records holding Lists compare by list identity.
      expect(t.repo.savedInterests?.categories, ['fashion']);
      expect(t.repo.savedInterests?.interests, ['fashion_shoes']);
      expect(t.repo.savedInterests?.customs, ['Anime']);
    });
  });

  group('colour selection', () {
    test('caps at four', () {
      final t = build();
      final c = controllerOf(t.container);

      for (final key in ['a', 'b', 'c', 'd', 'e']) {
        c.toggleColor(key);
      }

      expect(stateOf(t.container).selectedColors, ['a', 'b', 'c', 'd']);
    });

    test('saveColors posts the picks', () async {
      final t = build();
      controllerOf(t.container).toggleColor('purple_plum');

      await controllerOf(t.container).saveColors();

      expect(t.repo.savedColors, ['purple_plum']);
    });
  });

  group('size & fit', () {
    test('selections toggle off when tapped again', () {
      final t = build();
      final c = controllerOf(t.container);

      c.setClothingSize('xs');
      c.setClothingSize('xs');

      expect(stateOf(t.container).clothingSize, isNull);
    });

    test('switching shoe system clears the chosen size', () {
      final t = build();
      final c = controllerOf(t.container);
      c.setShoeSize('uk_9');

      c.setShoeSystem('eu');

      expect(stateOf(t.container).shoeSize, isNull);
      expect(stateOf(t.container).shoeSystem, 'eu');
    });

    test('saveSizes sends only what was chosen', () async {
      final t = build();
      final c = controllerOf(t.container);
      c.setClothingSize('xs');
      c.setFitPreference('regular');

      await c.saveSizes();

      expect(t.repo.savedSizes, (clothing: 'xs', shoe: null, fit: 'regular'));
    });
  });

  group('important dates', () {
    test('addDate stores server-confirmed entries', () async {
      final t = build();

      final ok = await controllerOf(t.container).addDate(
        personName: 'Ananya',
        relation: 'Best Friend',
        occasionKey: 'birthday',
        dateIso: '1999-08-17',
      );

      expect(ok, isTrue);
      expect(stateOf(t.container).savedDates.single.personName, 'Ananya');
      expect(t.repo.dates.single.occasionKey, 'birthday');
    });

    test('removeDate deletes locally and remotely', () async {
      final t = build();
      await controllerOf(t.container).addDate(
        personName: 'A',
        relation: 'B',
        occasionKey: 'birthday',
        dateIso: '2000-01-01',
      );
      final id = stateOf(t.container).savedDates.single.id;

      await controllerOf(t.container).removeDate(id);

      expect(stateOf(t.container).savedDates, isEmpty);
      expect(t.repo.dates, isEmpty);
    });
  });

  group('finish', () {
    test('marks the flow finished', () async {
      final t = build();
      expect(await controllerOf(t.container).finish(), isTrue);
      expect(stateOf(t.container).finished, isTrue);
      expect(t.repo.completed, isTrue);
    });

    test('treats already-complete as success', () async {
      final t = build()
        ..repo.completeFailure = const ApiException(
          code: 'ONBOARDING_ALREADY_COMPLETE',
          message: 'done',
          statusCode: 409,
        );

      expect(await controllerOf(t.container).finish(), isTrue);
      expect(stateOf(t.container).finished, isTrue);
    });

    test('surfaces other failures and stays unfinished', () async {
      final t = build()
        ..repo.completeFailure = const ApiException(
          code: ApiException.codeNetwork,
          message: 'down',
        );

      expect(await controllerOf(t.container).finish(), isFalse);
      expect(stateOf(t.container).finished, isFalse);
      expect(stateOf(t.container).error, isNotNull);
    });
  });
}
