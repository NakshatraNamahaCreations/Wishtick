import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/wishmates/presentation/widgets/person_avatar.dart';

import '../../helpers/wishmates_fakes.dart';

/// Whose face a row draws, and in which order.
///
/// The bug this fixes: the graph carried only `photoUrl`, so somebody who
/// picked one of the twenty bundled avatars during onboarding looked correct
/// to themselves and appeared to everybody else as a bare initial. Onboarding
/// offers the bundled set before it offers an upload, so that was most
/// accounts.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pump();
  }

  testWidgets('a bundled avatar is drawn for everyone, not just its owner', (
    tester,
  ) async {
    await pump(
      tester,
      PersonAvatar(person: buildIdentity(avatarKey: 'avatar_07')),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/avatar/07.png');
    expect(find.text('R'), findsNothing);
  });

  testWidgets('an uploaded photo wins over a bundled avatar', (tester) async {
    await pump(
      tester,
      PersonAvatar(
        person: buildIdentity(
          photoUrl: 'https://cdn.test/me.jpg',
          avatarKey: 'avatar_07',
        ),
      ),
    );

    // The asset must not be reached: a stale key left behind by an upload
    // would otherwise override the photo the person actually chose.
    // `WishtickImage` renders an `Image` of its own, so the assertion is on
    // the provider rather than on the widget type.
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .where((i) => i.image is AssetImage),
      isEmpty,
    );
  });

  testWidgets('somebody with neither gets an initial, not a stock face', (
    tester,
  ) async {
    await pump(tester, PersonAvatar(person: buildIdentity()));

    // Deliberately NOT avatar_01. ProfileAvatar falls back to it for the
    // signed-in user, which would make every unset account here identical.
    expect(find.byType(Image), findsNothing);
    expect(find.text('R'), findsOneWidget);
  });

  testWidgets('an avatar key the app does not ship falls back to the initial', (
    tester,
  ) async {
    await pump(
      tester,
      PersonAvatar(person: buildIdentity(avatarKey: 'avatar_99')),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.text('R'), findsOneWidget);
  });

  // 100 disc inside a 10-px ring, as `4177:267` measures it. The face keeps its
  // size and the halo is added outside — the other way round would draw the
  // hero's face 20 px smaller than the frame's while still occupying 120.
  //
  // Both presence states, because they take different paths through the
  // widget: offline returns the halo directly, online wraps it in a Stack so
  // the dot can sit across its edge. Testing only one lets the other regress.
  for (final online in [false, true]) {
    testWidgets('the halo grows the mark without shrinking the face '
        '(${online ? 'online' : 'offline'})', (tester) async {
      await pump(
        tester,
        PersonAvatar(
          person: buildIdentity(online: online),
          diameter: 100,
          ringColor: const Color(0x22FFFFFF),
        ),
      );

      expect(tester.getSize(find.byType(PersonAvatar)), const Size(120, 120));

      // And the disc keeps its own 100 inside that. Matched across every
      // Container rather than by position, because the online path adds the
      // presence dot and would otherwise move whichever one is "last".
      final sizes = find
          .descendant(
            of: find.byType(PersonAvatar),
            matching: find.byType(Container),
          )
          .evaluate()
          .map((e) => e.size)
          .toList();
      expect(sizes, contains(const Size(100, 100)));
      expect(sizes, contains(const Size(120, 120)));
    });
  }
}
