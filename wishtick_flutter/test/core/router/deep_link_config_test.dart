import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/router/deep_links.dart';

/// Keeps the four places that have to agree about a link in step.
///
/// A shareable URL is described in Dart ([AppLinks]), in the Android manifest,
/// in the iOS association file, and in the router's guard. Nothing connects
/// them at compile time, and the failure mode is silent and remote: a link
/// somebody was sent opens the browser instead of the app, or opens the app and
/// bounces them to the sign-in carousel. `/m/` had already drifted that way —
/// documented as a public contribute link, claimed as a deep link, and
/// redirected to /welcome by the guard.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('the Android manifest claims exactly the prefixes Dart does', () {
    final declared = RegExp(
      r'android:pathPrefix="([^"]+)"',
    ).allMatches(manifest).map((m) => m.group(1)!).toSet();

    expect(
      declared,
      AppLinks.claimedPrefixes.toSet(),
      reason:
          'A prefix in one and not the other is a link that resolves in the '
          'app but is never handed to it by Android (or the reverse). Update '
          'AppLinks.claimedPrefixes and the manifest together.',
    );
  });

  test('the iOS association file claims the same prefixes', () {
    final aasa =
        jsonDecode(
              File(
                '../deeplinks/apple-app-site-association',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    final components =
        ((aasa['applinks'] as Map<String, dynamic>)['details'] as List<dynamic>)
            .expand((d) => (d as Map<String, dynamic>)['components'] as List)
            .map((c) => (c as Map<String, dynamic>)['/'] as String)
            .toSet();

    expect(
      components,
      AppLinks.claimedPrefixes.map((p) => '$p*').toSet(),
      reason: 'iOS would route a different set of paths than Android does.',
    );
  });

  test('the manifest verifies the host Dart builds links for', () {
    final host = Uri.parse(AppLinks.origin).host;

    expect(manifest, contains('android:host="$host"'));
    // autoVerify is what makes Android fetch assetlinks.json; without it the
    // links still open a chooser rather than going straight to the app.
    expect(manifest, contains('android:autoVerify="true"'));
    // Without this, Flutter never hands the incoming route to go_router — and
    // it only counts *inside* <activity>. At <application> level Android
    // accepts the manifest and Flutter silently ignores it, so every deep link
    // opens the app at its start route and looks like a routing bug. Checking
    // only that the string is present somewhere is what let that through.
    final activity = RegExp(
      r'<activity[\s\S]*?</activity>',
    ).firstMatch(manifest)!.group(0)!;
    expect(
      activity,
      contains('flutter_deeplinking_enabled'),
      reason:
          'flutter_deeplinking_enabled must be a child of <activity>, not of '
          '<application>.',
    );
  });

  test('the custom scheme is registered on both platforms', () {
    expect(manifest, contains('android:scheme="${AppLinks.scheme}"'));
    expect(
      File('ios/Runner/Info.plist').readAsStringSync(),
      contains('<string>${AppLinks.scheme}</string>'),
    );
  });

  group('handles', () {
    test('accepts the claimed paths on the real host, with or without www', () {
      for (final url in [
        AppLinks.eventInvite('abc'),
        AppLinks.publicEvent('summer-party'),
        AppLinks.publicWishlist('jay-birthday'),
        AppLinks.memoryInvite('capsule'),
        'https://www.wishtick.com/i/abc',
        'wishtick://i/abc',
      ]) {
        expect(AppLinks.handles(Uri.parse(url)), isTrue, reason: url);
      }
    });

    test('leaves the rest of the site alone — the app claims share links, not '
        'the marketing pages', () {
      for (final url in [
        'https://wishtick.com/',
        'https://wishtick.com/pricing',
        'https://wishtick.com/blog/i-love-gifting',
      ]) {
        expect(AppLinks.handles(Uri.parse(url)), isFalse, reason: url);
      }
    });

    test('refuses a lookalike host — the path alone must never be enough', () {
      for (final url in [
        'https://wishtick.com.evil.test/i/abc',
        'https://notwishtick.com/i/abc',
        'https://evil.test/i/abc',
      ]) {
        expect(AppLinks.handles(Uri.parse(url)), isFalse, reason: url);
      }
    });
  });
}
