import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_colors.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_bottom_nav.dart';

void main() {
  Future<void> pumpNav(
    WidgetTester tester, {
    required ThemeData theme,
    int currentIndex = 0,
    ValueChanged<int>? onDestinationSelected,
    VoidCallback? onCreate,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          bottomNavigationBar: WishtickBottomNav(
            currentIndex: currentIndex,
            onDestinationSelected: onDestinationSelected ?? (_) {},
            onCreate: onCreate ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('renders four tabs and the create button', (tester) async {
    await pumpNav(tester, theme: AppTheme.light);

    for (final item in WishtickBottomNav.items) {
      expect(find.text(item.label), findsOneWidget);
    }
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('reports the tapped destination index', (tester) async {
    final tapped = <int>[];
    await pumpNav(
      tester,
      theme: AppTheme.light,
      onDestinationSelected: tapped.add,
    );

    await tester.tap(find.text('Profile'));
    await tester.pump();

    // Profile is the fourth destination; the create button is not a tab.
    expect(tapped, [3]);
  });

  testWidgets('create button is separate from tab selection', (tester) async {
    var created = 0;
    final tapped = <int>[];
    await pumpNav(
      tester,
      theme: AppTheme.light,
      onDestinationSelected: tapped.add,
      onCreate: () => created++,
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(created, 1);
    expect(tapped, isEmpty);
  });

  testWidgets('marks only the current tab as selected', (tester) async {
    await pumpNav(tester, theme: AppTheme.light, currentIndex: 1);

    final selected = tester.widget<Icon>(
      find.byIcon(WishtickBottomNav.items[1].activeIcon),
    );
    expect(selected.color, WishtickColors.light.navSelected);

    final unselected = tester.widget<Icon>(
      find.byIcon(WishtickBottomNav.items[0].icon),
    );
    expect(unselected.color, WishtickColors.light.navUnselected);
  });

  testWidgets('takes its colours from the active theme', (tester) async {
    await pumpNav(tester, theme: AppTheme.dark, currentIndex: 0);

    final selected = tester.widget<Icon>(
      find.byIcon(WishtickBottomNav.items[0].activeIcon),
    );
    expect(selected.color, WishtickColors.dark.navSelected);
    expect(selected.color, isNot(WishtickColors.light.navSelected));
  });
}
