import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishtick_flutter/core/router/app_shell.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';

/// The Android back button on the tab bar.
///
/// It used to close the app on the first press. A tab bar is where somebody
/// idles, so it is also where a stray back tap lands, and losing what you were
/// half way through to one is the kind of thing nobody reports — they just
/// stop trusting the button.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every `SystemNavigator.pop` the app asked for — leaving is a platform
  /// call, so this is what "the app closed" looks like from a test.
  late List<String> platformCalls;

  setUp(() {
    platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// The real shell, with two branches and a page a tab can push — so the
  /// question "did back pop a page or offer to leave?" is a real one.
  Future<void> pump(
    WidgetTester tester, {
    required QuitConfirmation confirmQuit,
  }) async {
    final rootKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: rootKey,
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              AppShell(navigationShell: shell, confirmQuit: confirmQuit),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, _) => const Scaffold(body: Text('home')),
                  routes: [
                    GoRoute(
                      path: 'deeper',
                      builder: (_, _) => const Scaffold(body: Text('deeper')),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/wishlist',
                  builder: (_, _) => const Scaffold(body: Text('wishlist')),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('back at a tab root asks before closing', (tester) async {
    var asked = 0;
    await pump(
      tester,
      confirmQuit: (_) async {
        asked++;
        return false;
      },
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(asked, 1);
    // Said no: still here, and the app was never asked to close.
    expect(find.text('home'), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
  });

  testWidgets('confirming closes the app', (tester) async {
    await pump(tester, confirmQuit: (_) async => true);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(platformCalls, contains('SystemNavigator.pop'));
  });

  testWidgets('back inside a tab pops that page and asks nothing', (
    tester,
  ) async {
    // The confirmation is only for the press that would actually leave. A
    // dialog every time you backed out of a screen would be unusable.
    var asked = 0;
    await pump(
      tester,
      confirmQuit: (_) async {
        asked++;
        return true;
      },
    );

    GoRouter.of(tester.element(find.text('home'))).go('/home/deeper');
    await tester.pumpAndSettle();
    expect(find.text('deeper'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(asked, 0);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
  });

  testWidgets('the default dialog offers Stay and Close, and Stay wins a '
      'stray tap', (tester) async {
    // Exercises the real dialog rather than a stub: the wording and which
    // answer is the safe one are the whole point of it.
    await pump(tester, confirmQuit: defaultQuitConfirmation);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Close Wishtick?'), findsOneWidget);
    expect(find.text('Stay'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(find.text('Close Wishtick?'), findsNothing);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
  });

  testWidgets('the default dialog closes the app on Close', (tester) async {
    await pump(tester, confirmQuit: defaultQuitConfirmation);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(platformCalls, contains('SystemNavigator.pop'));
  });

  testWidgets('dismissing the dialog by tapping away keeps the app open', (
    tester,
  ) async {
    await pump(tester, confirmQuit: defaultQuitConfirmation);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // The barrier: a null answer must read as "stay", never as "leave".
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Close Wishtick?'), findsNothing);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
  });
}
