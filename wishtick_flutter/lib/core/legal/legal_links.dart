import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Which hosted document to open.
enum LegalDoc {
  terms('Terms of Use', LegalLinks.terms),
  privacy('Privacy Policy', LegalLinks.privacy);

  const LegalDoc(this.title, this.url);

  final String title;
  final String url;
}

/// Opens a hosted legal document in the browser, telling the user if it will
/// not open rather than failing silently.
///
/// The Privacy Policy also has an in-app screen (`2262:1019`); this is for the
/// documents that only exist as hosted pages.
Future<void> openLegalLink(BuildContext context, LegalDoc doc) async {
  final opened = await launchUrl(
    Uri.parse(doc.url),
    mode: LaunchMode.externalApplication,
  );
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Could not open the ${doc.title}.')));
}

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
