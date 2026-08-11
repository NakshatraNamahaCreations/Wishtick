/// Where the Terms and Privacy links point.
///
/// Overridable at build time, the same way the API host is:
/// `flutter run --dart-define=WISHTICK_TERMS_URL=https://…`
///
/// The app has no in-app legal screens yet (Sprint 9), so these open the
/// hosted documents in the browser. Defaults are the wishtick.app paths that
/// match the API host convention — correct them here if marketing publishes
/// them elsewhere; nothing else in the app hard-codes a legal URL.
abstract final class LegalLinks {
  static const terms = String.fromEnvironment(
    'WISHTICK_TERMS_URL',
    defaultValue: 'https://wishtick.app/terms',
  );

  static const privacy = String.fromEnvironment(
    'WISHTICK_PRIVACY_URL',
    defaultValue: 'https://wishtick.app/privacy',
  );
}
