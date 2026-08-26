import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where to go once the user finishes signing in.
///
/// Somebody arriving from a share link has just installed the app and is
/// signed out. They tap Sign in, and by the time they are through OTP — and
/// possibly the whole onboarding wizard — the router's own rule takes over:
/// *authenticated user in the auth flow → Home*. The invitation they came for
/// is gone, and nothing on Home mentions it.
///
/// So the screen that sends them to sign in leaves the destination here first,
/// and the redirect spends it instead of going Home.
///
/// A plain mutable field rather than a `StateProvider` on purpose: this is read
/// and cleared *inside* `GoRouter.redirect`, which runs during routing.
/// Mutating provider state there would notify listeners mid-navigation; nothing
/// needs to rebuild when this changes, only the next redirect needs to see it.
class PendingDeepLink {
  String? _location;

  /// Remembers [location] as the place to return to after signing in.
  void remember(String location) => _location = location;

  /// Returns the remembered location once, clearing it.
  ///
  /// Consuming rather than peeking is what stops the app bouncing back to an
  /// invitation every time the user later signs out and in again.
  String? take() {
    final location = _location;
    _location = null;
    return location;
  }

  /// Drops it without using it — a user who backs out of signing in is not
  /// still on their way to the invitation.
  void clear() => _location = null;
}

final pendingDeepLinkProvider = Provider<PendingDeepLink>(
  (ref) => PendingDeepLink(),
);
