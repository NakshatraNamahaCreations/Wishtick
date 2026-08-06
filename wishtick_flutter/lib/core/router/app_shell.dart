import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/quick_add_sheet.dart';
import '../widgets/wishtick_bottom_nav.dart';

/// Hosts the four tab branches and the bottom navigation.
///
/// [StatefulNavigationShell] keeps a separate navigator per branch, so each tab
/// remembers its own scroll position and page stack across switches.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the tab you are already on pops back to its root.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: WishtickBottomNav(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        onCreate: () => _showCreateSheet(context),
      ),
    );
  }

  /// The centre button opens the create menu (wishlist / event / memory).
  void _showCreateSheet(BuildContext context) {
    unawaited(QuickAddSheet.show(context));
  }
}
