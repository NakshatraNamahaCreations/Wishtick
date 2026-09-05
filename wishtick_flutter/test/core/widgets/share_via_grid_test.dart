import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:wishtick_flutter/core/theme/app_colors.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/widgets/share_via_grid.dart';

/// The share grid (`288:780`): each tile is the service's own mark on its own
/// colour, not a themed stand-in.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    ThemeData? theme,
    bool enabled = true,
    ValueChanged<ShareTarget>? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(
          body: ShareViaGrid(enabled: enabled, onTap: onTap ?? (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  BoxDecoration markOf(WidgetTester tester, ShareTarget target) =>
      tester
              .widget<Container>(
                find.byKey(ValueKey('share-mark-${target.name}')),
              )
              .decoration!
          as BoxDecoration;

  testWidgets('every tile carries the service\'s own mark', (tester) async {
    await pump(tester);

    const marks = {
      ShareTarget.copyLink: FontAwesomeIcons.link,
      ShareTarget.whatsapp: FontAwesomeIcons.whatsapp,
      ShareTarget.instagram: FontAwesomeIcons.instagram,
      ShareTarget.facebook: FontAwesomeIcons.facebookF,
      ShareTarget.snapchat: FontAwesomeIcons.snapchat,
      ShareTarget.telegram: FontAwesomeIcons.solidPaperPlane,
      ShareTarget.twitter: FontAwesomeIcons.xTwitter,
      ShareTarget.moreApps: FontAwesomeIcons.ellipsis,
    };
    for (final entry in marks.entries) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('share-mark-${entry.key.name}')),
          // A Font Awesome glyph wraps an IconData; FaIcon exposes that one.
          matching: find.byIcon(entry.value.data),
        ),
        findsOneWidget,
        reason: entry.key.name,
      );
    }
    // Nothing from the Material set survives — those were the stand-ins.
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);
  });

  testWidgets('each mark sits on its brand colour, which ignores the theme', (
    tester,
  ) async {
    const brand = WishtickColors.light;
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await pump(tester, theme: theme);

      expect(
        markOf(tester, ShareTarget.whatsapp).color,
        brand.shareBrand.whatsApp,
      );
      expect(
        markOf(tester, ShareTarget.facebook).color,
        brand.shareBrand.facebook,
      );
      expect(
        markOf(tester, ShareTarget.telegram).color,
        brand.shareBrand.telegram,
      );
      expect(
        markOf(tester, ShareTarget.snapchat).color,
        brand.shareBrand.snapchat,
      );
      expect(markOf(tester, ShareTarget.twitter).color, brand.shareBrand.x);
      expect(markOf(tester, ShareTarget.copyLink).color, brand.shareBrand.link);
    }
  });

  testWidgets(
    'only "More Apps", the one tile that is ours, follows the theme',
    (tester) async {
      await pump(tester, theme: AppTheme.light);
      final light = markOf(tester, ShareTarget.moreApps).color;
      await pump(tester, theme: AppTheme.dark);
      final dark = markOf(tester, ShareTarget.moreApps).color;

      expect(light, WishtickColors.light.shareBrand.moreFill);
      expect(dark, WishtickColors.dark.shareBrand.moreFill);
      expect(light, isNot(dark));
    },
  );

  testWidgets('Instagram is a gradient, and it and Snapchat are rounded '
      'squares; the rest are discs', (tester) async {
    await pump(tester);

    final instagram = markOf(tester, ShareTarget.instagram);
    expect(instagram.gradient, isA<LinearGradient>());
    expect(
      (instagram.gradient! as LinearGradient).colors,
      WishtickColors.light.shareBrand.instagram,
    );
    expect(instagram.shape, BoxShape.rectangle);
    expect(instagram.borderRadius, isNotNull);

    expect(markOf(tester, ShareTarget.snapchat).shape, BoxShape.rectangle);

    for (final disc in [
      ShareTarget.copyLink,
      ShareTarget.whatsapp,
      ShareTarget.facebook,
      ShareTarget.telegram,
      ShareTarget.twitter,
      ShareTarget.moreApps,
    ]) {
      expect(markOf(tester, disc).shape, BoxShape.circle, reason: disc.name);
      expect(markOf(tester, disc).gradient, isNull, reason: disc.name);
    }
  });

  testWidgets('the glyph on the yellow is dark; on the others it is light', (
    tester,
  ) async {
    await pump(tester);

    Color inkOf(ShareTarget target) => tester
        .widget<FaIcon>(
          find.descendant(
            of: find.byKey(ValueKey('share-mark-${target.name}')),
            matching: find.byType(FaIcon),
          ),
        )
        .color!;

    expect(
      inkOf(ShareTarget.snapchat),
      WishtickColors.light.shareBrand.onSnapchat,
    );
    expect(
      inkOf(ShareTarget.whatsapp),
      WishtickColors.light.shareBrand.onBrand,
    );
    expect(inkOf(ShareTarget.twitter), WishtickColors.light.shareBrand.onBrand);
  });

  testWidgets('a tap names its target, and a disabled grid arms nothing', (
    tester,
  ) async {
    final tapped = <ShareTarget>[];
    await pump(tester, onTap: tapped.add);

    await tester.tap(find.text('Telegram'));
    expect(tapped, [ShareTarget.telegram]);

    await pump(tester, enabled: false, onTap: tapped.add);
    await tester.tap(find.text('Telegram'));
    expect(tapped, hasLength(1));
  });
}
