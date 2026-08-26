/// The shape of a shareable Wishtick link, in one place.
///
/// Three things have to agree on these strings and they live in three
/// different repositories: this app's router, the Android manifest's
/// `pathPrefix` list, and the website that serves the URL to somebody who does
/// not have the app. Anything that builds a link builds it from here.
///
/// **The paths are deliberately the same as the in-app routes** (`AppRoutes`),
/// so `https://wishtick.com/i/abc` and the internal route `/i/abc` are the same
/// string. `go_router` then needs no translation layer: Flutter hands it the
/// path of the incoming link and the existing route matches it.
abstract final class AppLinks {
  /// Where a shared link points. Overridable so a staging build can point
  /// somewhere else without a code change:
  /// `--dart-define=WISHTICK_LINK_ORIGIN=https://staging.wishtick.com`
  static const origin = String.fromEnvironment(
    'WISHTICK_LINK_ORIGIN',
    defaultValue: 'https://wishtick.com',
  );

  /// The custom scheme, for testing the routing before the site exists.
  ///
  /// Not a substitute for the https link: nobody without the app can tap
  /// `wishtick://…` from a chat, and it offers no way to reach the store.
  static const scheme = 'wishtick';

  /// One person's invitation to an event — the accept/decline screen.
  /// The token *is* the authorization, so it is unguessable and not a slug.
  static String eventInvite(String token) => '$origin/i/$token';

  /// A public event's open invitation. Unlike [eventInvite] this is one link
  /// for everybody, so whoever opens it is identified by *signing in*, not by
  /// the link — see `POST /events/:slug/join`.
  static String publicEvent(String slug) => '$origin/e/$slug';

  /// A wishlist somebody made shareable.
  static String publicWishlist(String slug) => '$origin/w/$slug';

  /// A memory capsule's contribute link.
  static String memoryInvite(String slug) => '$origin/m/$slug';

  /// Every path prefix the app claims. Must match the `pathPrefix` entries in
  /// `android/app/src/main/AndroidManifest.xml` and the `paths` in the iOS
  /// `apple-app-site-association`.
  ///
  /// Claiming the bare host instead would have the app swallow every link to
  /// the marketing site, including pages it has no screen for.
  static const claimedPrefixes = ['/i/', '/e/', '/w/', '/m/'];

  /// Whether [url] is one this app can open. Used to decide whether a link
  /// pasted or received in-app should be routed internally rather than handed
  /// to the browser.
  static bool handles(Uri url) {
    if (url.scheme == scheme) return true;
    final host = url.host.toLowerCase();
    final origin_ = Uri.parse(origin).host.toLowerCase();
    if (host != origin_ && host != 'www.$origin_') return false;
    return claimedPrefixes.any((p) => url.path.startsWith(p));
  }
}
