import 'package:flutter/foundation.dart';

/// Whether the app runs against in-memory fakes instead of the real API.
///
/// **This bypasses authentication entirely — any number, any code.** It exists
/// so the UI can be walked before the backend is reachable, and it is locked
/// down two ways:
///
///  1. Opt-in only — `--dart-define=WISHTICK_FAKE_BACKEND=true`.
///  2. Debug builds only — [kDebugMode] is a compile-time constant, so in a
///     release or profile build this folds to `false` and the fake code is
///     tree-shaken out even if someone passes the define.
///
/// A "FAKE API" banner is shown whenever it is active, so screenshots and bug
/// reports can never be mistaken for the real thing.
abstract final class DevMode {
  static const _requested = bool.fromEnvironment('WISHTICK_FAKE_BACKEND');

  static bool get fakeBackend => _requested && kDebugMode;
}
