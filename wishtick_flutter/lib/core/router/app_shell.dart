import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
  /// Sprints 3, 7 and 8 fill in the destinations.
  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _CreatePlaceholderSheet(),
    );
  }
}

class _CreatePlaceholderSheet extends StatelessWidget {
  const _CreatePlaceholderSheet();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Create — wired up in Sprints 3, 7 and 8.'),
      ),
    );
  }
}
