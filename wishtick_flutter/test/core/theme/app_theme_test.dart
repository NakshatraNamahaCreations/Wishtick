import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_colors.dart';
import 'package:wishtick_flutter/core/theme/app_dimens.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/theme/theme_extensions.dart';

/// WCAG 2.1 contrast ratio between two opaque colours: 1.0 (identical) to
/// 21.0 (black on white). AA wants 4.5:1 for body text.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('AppTheme', () {
    test('exposes the Wishtick tokens on both themes', () {
      expect(AppTheme.light.extension<WishtickColors>(), isNotNull);
      expect(AppTheme.dark.extension<WishtickColors>(), isNotNull);
    });

    test('carries the matching brightness', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(
        AppTheme.light.extension<WishtickColors>()!.brightness,
        Brightness.light,
      );
      expect(
        AppTheme.dark.extension<WishtickColors>()!.brightness,
        Brightness.dark,
      );
    });

    test('drives scaffold and colour scheme from the tokens', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final colors = theme.extension<WishtickColors>()!;
        expect(theme.scaffoldBackgroundColor, colors.background);
        expect(theme.colorScheme.primary, colors.primary);
        expect(theme.colorScheme.surface, colors.surface);
        expect(theme.colorScheme.error, colors.danger);
      }
    });

    test('the primary button is a rounded rect, not a full pill — sampled '
        'off the exports at ~8-12px against a ~53px button height', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final shape =
            theme.elevatedButtonTheme.style!.shape!.resolve({})!
                as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(AppRadius.md));
      }
    });
  });

  group('WishtickColors', () {
    test('the page colour is the one design confirmed', () {
      // #FAF7F2, confirmed by design — it supersedes the #F5ECE4 sampled off
      // the frame exports. Pinned here because it is the colour behind every
      // screen in the app, and a drift would be visible everywhere at once.
      expect(WishtickColors.light.background, const Color(0xFFFAF7F2));
    });

    test('light and dark actually differ on surfaces and text', () {
      const light = WishtickColors.light;
      const dark = WishtickColors.dark;

      expect(light.background, isNot(dark.background));
      expect(light.surface, isNot(dark.surface));
      expect(light.textPrimary, isNot(dark.textPrimary));
    });

    test('text sits on the correct side of its background in each theme', () {
      for (final colors in [WishtickColors.light, WishtickColors.dark]) {
        final backgroundIsDark =
            ThemeData.estimateBrightnessForColor(colors.background) ==
            Brightness.dark;
        final textIsLight =
            ThemeData.estimateBrightnessForColor(colors.textPrimary) ==
            Brightness.dark;
        expect(
          backgroundIsDark,
          isNot(textIsLight),
          reason:
              'textPrimary must contrast with background in '
              '${colors.brightness} mode',
        );
      }
    });

    test('every foreground meets WCAG AA on its background', () {
      for (final colors in [WishtickColors.light, WishtickColors.dark]) {
        final pairs = <String, (Color, Color)>{
          'onPrimary/primary': (colors.onPrimary, colors.primary),
          'onAccent/accent': (colors.onAccent, colors.accent),
          'onDanger/danger': (colors.onDanger, colors.danger),
          'textOnDark/primaryDeep': (colors.textOnDark, colors.primaryDeep),
          'textPrimary/surface': (colors.textPrimary, colors.surface),
          'textPrimary/surfaceAlt': (colors.textPrimary, colors.surfaceAlt),
          'textSecondary/surface': (colors.textSecondary, colors.surface),
          // Regression: the RSVP pills on the guest list took `success` on
          // `successSubtle` — #3FBFA6 on #7FD9C6, 1.7:1 — and the label was
          // unreadable on the phone. These two tokens exist so the ink can
          // invert with the fill between themes.
          'onSuccessSubtle/successSubtle': (
            colors.onSuccessSubtle,
            colors.successSubtle,
          ),
          'onWarningSubtle/warningSubtle': (
            colors.onWarningSubtle,
            colors.warningSubtle,
          ),
          'onDangerSubtle/dangerSubtle': (
            colors.onDangerSubtle,
            colors.dangerSubtle,
          ),
        };

        pairs.forEach((name, pair) {
          final (foreground, background) = pair;
          expect(
            contrastRatio(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: '$name falls below AA (4.5:1) in ${colors.brightness} mode',
          );
        });
      }
    });

    // Regression: outlined and text buttons took `primary` as their
    // foreground in both themes. In dark that is #5B1A6E on #17101B — 1.61:1,
    // and on a real phone the label all but disappeared. Found by walking the
    // app in dark mode, not by any test.
    test('outlined and text button labels meet AA on the page', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final colors = theme.extension<WishtickColors>()!;
        final outlined = theme.outlinedButtonTheme.style!.foregroundColor!
            .resolve({})!;
        final text = theme.textButtonTheme.style!.foregroundColor!.resolve({})!;

        for (final entry in {'outlined': outlined, 'text': text}.entries) {
          expect(
            contrastRatio(entry.value, colors.background),
            greaterThanOrEqualTo(4.5),
            reason:
                '${entry.key} button label falls below AA on the page in '
                '${colors.brightness} mode',
          );
        }
      }
    });

    // Regression: the floating label and the focused border both took
    // `primary`. On the dark field (#2E2233) that is ~1.2:1 — every labelled
    // input in the app lost its label in dark mode. Found on a phone, on the
    // relation field of `257:733`.
    test('the input label reads on its own field in both themes', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final colors = theme.extension<WishtickColors>()!;
        final label = theme.inputDecorationTheme.floatingLabelStyle!.color!;
        expect(
          contrastRatio(label, colors.surfaceAlt),
          greaterThanOrEqualTo(4.5),
          reason:
              'the floating label falls below AA on the field in '
              '${colors.brightness} mode',
        );
      }
    });

    test('status colours stay distinguishable from the surface', () {
      for (final colors in [WishtickColors.light, WishtickColors.dark]) {
        for (final status in {
          'success': colors.success,
          'danger': colors.danger,
          'warning': colors.warning,
        }.entries) {
          expect(
            status.value,
            isNot(colors.surface),
            reason:
                '${status.key} blends into the surface in '
                '${colors.brightness} mode',
          );
        }
      }
    });

    test('navigation reads against its own background in both themes', () {
      for (final colors in [WishtickColors.light, WishtickColors.dark]) {
        expect(colors.navSelected, isNot(colors.navBackground));
        expect(colors.navUnselected, isNot(colors.navBackground));
        expect(
          colors.navSelected,
          isNot(colors.navUnselected),
          reason:
              'selected and unselected tabs are indistinguishable in '
              '${colors.brightness} mode',
        );
      }
    });

    test('lerp interpolates between the two themes', () {
      const light = WishtickColors.light;
      final mid = light.lerp(WishtickColors.dark, 0.5);

      expect(mid.background, isNot(light.background));
      expect(mid.background, isNot(WishtickColors.dark.background));
      expect(light.lerp(WishtickColors.dark, 0).background, light.background);
      expect(
        light.lerp(WishtickColors.dark, 1).background,
        WishtickColors.dark.background,
      );
    });

    test('copyWith replaces only the named token', () {
      const light = WishtickColors.light;
      final copy = light.copyWith(primary: const Color(0xFF123456));

      expect(copy.primary, const Color(0xFF123456));
      expect(copy.background, light.background);
      expect(copy.textPrimary, light.textPrimary);
    });
  });

  group('context.colors', () {
    testWidgets('resolves the active theme tokens', (tester) async {
      late WishtickColors seen;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              seen = context.colors;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(seen.brightness, Brightness.dark);
      expect(seen.background, WishtickColors.dark.background);
    });

    testWidgets('falls back to light tokens without the extension', (
      tester,
    ) async {
      late WishtickColors seen;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              seen = context.colors;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(seen.background, WishtickColors.light.background);
    });
  });
}
