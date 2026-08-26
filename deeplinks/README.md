# Deep links — what the website has to serve

The app is wired for `https://wishtick.com` links. Three pieces are needed and
only the first is in this repo's control:

| Piece | Where | State |
|---|---|---|
| Intent filters / entitlements | `wishtick_flutter/android/…/AndroidManifest.xml`, `ios/Runner/Runner.entitlements` | ✅ done |
| The two verification files | `wishtick.com/.well-known/…` | ⛔ this folder — needs real values |
| The store fallback | the web page at `/i/`, `/e/`, `/w/`, `/m/` | ⛔ website work |

## The store fallback is the website's job, not the app's

Worth being explicit, because it is the one part that cannot be built here: when
somebody without the app taps `https://wishtick.com/i/abc`, **the app is not
there to redirect them**. Android and iOS simply open the URL in a browser. So
the page at that URL is what has to look at the User-Agent and send them to the
Play Store or the App Store — and, ideally, render the invitation itself so the
link is useful to somebody who never installs anything.

Once the app *is* installed and the domain is verified, the OS intercepts the
same URL before the browser ever sees it, and the page is never loaded.

## Claimed paths

Keep these three lists in step — `AppLinks.claimedPrefixes` in
`lib/core/router/deep_links.dart` is the source of truth:

| Path | Screen | Who can open it |
|---|---|---|
| `/i/<token>` | One person's event invitation — accept / decline | Anyone with the token |
| `/e/<slug>` | A public event's open invitation | Anyone, but must sign in to RSVP |
| `/w/<slug>` | A shared wishlist | Anyone with the link |
| `/m/<slug>` | A memory capsule's contribute link | Anyone with the link |

## Before these files work

Both templates below contain placeholders. **Neither will verify as-is.**

1. **The application id is still the Flutter default.** Android is
   `com.example.wishtick_flutter` and iOS is `com.example.wishtickFlutter`.
   Google Play rejects `com.example.*` outright, so this has to change before
   release — and because App Link verification binds to the id, changing it
   later means reissuing `assetlinks.json`. Worth settling before the first
   store upload rather than after.
2. **Android needs the release signing certificate's SHA-256**, not the debug
   one:
   ```bash
   keytool -list -v -keystore <release.keystore> -alias <alias> | grep SHA256
   ```
   Add the debug certificate's fingerprint to the same array while developing —
   the array takes several, so debug and release can both verify.
3. **iOS needs the Apple Team ID**, and `Runner.entitlements` must be attached
   to the target in Xcode (Signing & Capabilities → Associated Domains). Adding
   the file to the repo does not attach it to the build.

## Serving them

Both must be served over HTTPS, with no redirect, as
`application/json`, at exactly these paths:

- `https://wishtick.com/.well-known/assetlinks.json`
- `https://wishtick.com/.well-known/apple-app-site-association` (**no** `.json`
  extension)

Verify afterwards with:

```bash
# Android — should report each statement as verified
adb shell pm verify-app-links --re-verify com.example.wishtick_flutter
adb shell pm get-app-links com.example.wishtick_flutter

# iOS
curl -sS https://wishtick.com/.well-known/apple-app-site-association | jq .
```

## Testing before any of it is hosted

The custom scheme needs no verification and works today:

```bash
adb shell am start -a android.intent.action.VIEW -d "wishtick://i/some-token"
```

The https form can also be forced past verification while developing:

```bash
adb shell am start -a android.intent.action.VIEW -d "https://wishtick.com/i/some-token"
```
