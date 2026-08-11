import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/core/dev/dev_mode.dart';
import 'package:wishtick_flutter/core/dev/dev_repositories.dart';
import 'package:wishtick_flutter/core/dev/dev_taxonomy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the fake-backend switch', () {
    test('is off unless explicitly asked for', () {
      // The suite runs without the dart-define, so this must be false. If it
      // ever reads true here, the fake API is one careless build from shipping.
      expect(DevMode.fakeBackend, isFalse);
    });

    test('is guarded by kDebugMode in source, not just by convention', () {
      // Reading the source is the only way to assert the release guard from a
      // debug-mode test run: `kDebugMode` is a compile-time constant, so a
      // release build folds `fakeBackend` to false and tree-shakes the fakes.
      final source = File('lib/core/dev/dev_mode.dart').readAsStringSync();
      expect(
        source,
        contains('kDebugMode'),
        reason: 'DevMode must not be enable-able in a release build',
      );
    });
  });

  group('the fake taxonomy matches the backend seed shape', () {
    test('serves the 12 interest categories in design order', () {
      final options = DevTaxonomy.build();
      expect(options.interestCategories.first.key, 'fashion');
      expect(options.interestCategories.last.key, 'other');
      expect(options.interestCategories, hasLength(12));
    });

    test('every interest names a category that exists', () {
      final options = DevTaxonomy.build();
      final categories = options.interestCategories.map((c) => c.key).toSet();
      for (final interest in options.interests) {
        expect(
          categories,
          contains(interest.meta?['category']),
          reason: '${interest.key} points at an unknown category',
        );
      }
    });

    test('serves 40 colours, each grouped and with a hex', () {
      final options = DevTaxonomy.build();
      expect(options.colors, hasLength(40));
      expect(options.colorGroups, hasLength(8));
      for (final colour in options.colors) {
        expect(colour.meta?['hex'], matches(RegExp(r'^#[0-9A-F]{6}$')));
        expect(colour.meta?['groupLabel'], isNotEmpty);
      }
    });

    test('covers all three shoe-size systems', () {
      final options = DevTaxonomy.build();
      for (final system in ['uk', 'us', 'eu']) {
        expect(options.shoeSizesFor(system), isNotEmpty, reason: system);
      }
    });
  });

  group('DevAuthRepository', () {
    Future<DevAuthRepository> build() async {
      SharedPreferences.setMockInitialValues({});
      return DevAuthRepository(await SharedPreferences.getInstance());
    }

    test('accepts any number and any code', () async {
      final auth = await build();
      await auth.requestSignInCode('+919999999999');

      final result = await auth.verifySignInCode(
        phone: '+919999999999',
        code: '000000',
        name: 'Tester',
      );

      expect(result.user.phone, '+919999999999');
      expect(result.tokens.accessToken, isNotEmpty);
    });

    test('sends a first-time user through onboarding', () async {
      final auth = await build();
      final result = await auth.verifySignInCode(
        phone: '+911234567890',
        code: '123456',
      );
      expect(result.isNewUser, isTrue);
    });

    test('sends a *returning* user through onboarding as well', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await DevOnboardingRepository(prefs).complete();

      final result = await DevAuthRepository(
        prefs,
      ).verifySignInCode(phone: '+911234567890', code: '123456');

      // Deliberately unlike the real backend, which would know this user.
      // Signing in is how you reach signup in the fake, so it must not be a
      // one-time-per-install door.
      expect(result.isNewUser, isTrue);
    });

    test('clears the stored onboarding flag so a restore agrees', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await DevOnboardingRepository(prefs).complete();

      await DevAuthRepository(
        prefs,
      ).verifySignInCode(phone: '+911234567890', code: '123456');

      // Session.restore() re-reads this through DevOnboardingRepository. Left
      // set, it would contradict isNewUser and bounce the user out to Home on
      // the next launch — the two sources have to say the same thing.
      final status = await DevOnboardingRepository(prefs).status();
      expect(status.completed, isFalse);
      expect(status.remainingRequiredSteps, contains('profile'));
    });

    test('refuses the password flow rather than faking it', () async {
      final auth = await build();
      expect(
        () => auth.login(identifier: 'x', password: 'y'),
        throwsUnimplementedError,
      );
    });
  });

  group('DevOnboardingRepository', () {
    Future<DevOnboardingRepository> build() async {
      SharedPreferences.setMockInitialValues({});
      return DevOnboardingRepository(await SharedPreferences.getInstance());
    }

    test('completion survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await DevOnboardingRepository(prefs).complete();

      // A fresh repository over the same storage, as a relaunch would build.
      expect((await DevOnboardingRepository(prefs).status()).completed, isTrue);
    });

    test('stores and removes important dates', () async {
      final repo = await build();

      final saved = await repo.addImportantDate(
        personName: 'Ananya',
        relation: 'Best Friend',
        occasionKey: 'birthday',
        dateIso: '1999-08-17',
      );
      expect((await repo.listImportantDates()).single.personName, 'Ananya');

      await repo.removeImportantDate(saved.id);
      expect(await repo.listImportantDates(), isEmpty);
    });

    test('survives a name containing the JSON-unsafe characters', () async {
      final repo = await build();

      await repo.addImportantDate(
        // A delimited storage format would corrupt on these.
        personName: r'A|B"C\D',
        relation: 'Friend|Colleague',
        occasionKey: 'birthday',
        dateIso: '2000-01-01',
      );

      final read = (await repo.listImportantDates()).single;
      expect(read.personName, r'A|B"C\D');
      expect(read.relation, 'Friend|Colleague');
    });
  });
}
