import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../widgets/quick_add_sheet.dart';
import '../widgets/wishtick_bottom_nav.dart';

/// Asks before the back button closes the app.
///
/// Exposed so a widget test can answer it without a real dialog, and so the
/// one piece worth pinning — that leaving takes a deliberate second tap — is
/// testable apart from the platform call that actually leaves.
typedef QuitConfirmation = Future<bool> Function(BuildContext context);

/// Hosts the four tab branches and the bottom navigation.
///
/// [StatefulNavigationShell] keeps a separate navigator per branch, so each tab
/// remembers its own scroll position and page stack across switches.
class AppShell extends StatelessWidget {
  const AppShell({
    required this.navigationShell,
    this.confirmQuit = defaultQuitConfirmation,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  /// What the back button asks before closing the app.
  final QuitConfirmation confirmQuit;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the tab you are already on pops back to its root.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// Back at the root of a tab used to close the app on the first press.
  ///
  /// A tab bar is where somebody idles, so it is also where a stray back tap
  /// lands — and losing a half-written wishlist to one is the kind of thing
  /// nobody reports, they just stop trusting the button.
  ///
  /// Only reached when the branch has nothing left to pop: a pushed page
  /// inside a tab is popped by its own navigator and never gets this far, so
  /// the question is only ever asked when the answer really is "leave".
  Future<void> _onPop(BuildContext context, bool didPop) async {
    if (didPop) return;
    if (!await confirmQuit(context)) return;
    // Not `exit(0)`: this hands the app to the OS the way the home button
    // does, leaving it to be resumed rather than killing the process.
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => unawaited(_onPop(context, didPop)),
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: WishtickBottomNav(
          currentIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          onCreate: () => _showCreateSheet(context),
        ),
      ),
    );
  }

  /// The centre button opens the create menu (wishlist / event / memory).
  void _showCreateSheet(BuildContext context) {
    unawaited(QuickAddSheet.show(context));
  }
}

/// "Close Wishtick?" — the default [QuitConfirmation].
///
/// Staying is the safe answer, so it is the plain button and the one a stray
/// tap outside the dialog lands on.
Future<bool> defaultQuitConfirmation(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Close Wishtick?'),
      content: const Text('You can pick up where you left off next time.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Stay'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  return leave ?? false;
}
