/// What Wishtick writes when somebody shares something out of it.
///
/// One place, because the same thing was being described two different ways
/// depending on which button was pressed: an event shared from its own screen
/// carried the date and the venue, while the same event shared from the
/// WishMates sheet carried only its title. A reader cannot tell which button
/// the sender used, so the two readings were simply inconsistent.
///
/// Every message here follows the same three rules:
///
///  * **Who it is from.** A forwarded message loses its context, so the
///    sender's name is in the words rather than left to the chat header.
///  * **A link, always.** A share with nothing to tap is a dead end — the
///    reader cannot act on it and often cannot even tell what app it is about.
///  * **One format per thing.** The message is built here, not at the button.
library;

import 'package:intl/intl.dart';

import '../router/deep_links.dart';

/// "5 Sep 2026 · 7:20 PM" — the same format the invitation itself prints.
final _eventWhen = DateFormat('d MMM yyyy · h:mm a');

/// `Priya` → `Priya has invited…`, and nothing when the sender has no name.
///
/// An account can reach a share screen before it has filled in a name, and
/// "null has invited you" is worse than a message that simply does not say.
String? _from(String? senderName) {
  final name = senderName?.trim();
  return name == null || name.isEmpty ? null : name;
}

/// One share, ready to send: the words and the link that goes under them.
class ShareMessage {
  const ShareMessage({required this.text, required this.url});

  /// The words alone. Some channels take the text and the URL separately —
  /// Telegram and X do — so the two stay apart until the moment of sending.
  final String text;

  /// Where it points. Never empty: a share with nothing to tap is a dead end.
  final String url;

  /// The two together, for a channel that takes one blob — WhatsApp, the
  /// system sheet. The link on its own line so it stays tappable.
  String get combined => '$text\n$url';
}

/// An invitation to an event.
///
/// The long form everywhere. The short "You're invited to X" the WishMates
/// sheet used to send left the reader to open the link just to find out
/// whether they were free that day.
ShareMessage eventInvite({
  required String title,
  required DateTime startsAt,
  required String slug,
  String? venue,
  String? senderName,
}) {
  final where = venue?.trim();
  final at = where == null || where.isEmpty ? '' : ' at $where';
  final from = _from(senderName);
  final who = from == null ? "You're invited" : '$from has invited you';
  return ShareMessage(
    text:
        '$who to $title on ${_eventWhen.format(startsAt.toLocal())}$at. '
        'See the invitation on Wishtick',
    url: AppLinks.publicEvent(slug),
  );
}

/// Somebody's wishlist.
ShareMessage wishlist({
  required String title,
  required String slug,
  String? senderName,
}) {
  final from = _from(senderName);
  return ShareMessage(
    text: from == null
        ? 'Take a look at my wishlist "$title" on Wishtick'
        : 'Take a look at $from\'s wishlist "$title" on Wishtick',
    url: AppLinks.publicWishlist(slug),
  );
}

/// A group gift somebody is collecting for.
ShareMessage groupGift({
  required String title,
  required String url,
  String? senderName,
}) {
  final from = _from(senderName);
  return ShareMessage(
    text: from == null
        ? 'Chip in with me for $title on Wishtick'
        : 'Chip in with $from for $title on Wishtick',
    url: url,
  );
}

/// A memory capsule still collecting wishes.
ShareMessage memoryContribute({
  required String title,
  required DateTime unlockAt,
  required String slug,
  String? personName,
  String? senderName,
}) {
  final from = _from(senderName);
  final who = from == null ? 'Add a wish' : '$from is asking you to add a wish';
  final forWhom = personName == null || personName.trim().isEmpty
      ? ''
      : ' for ${personName.trim()}';
  return ShareMessage(
    text:
        '$who to $title$forWhom — it opens on '
        '${DateFormat('d MMM').format(unlockAt.toLocal())}.',
    url: AppLinks.memoryInvite(slug),
  );
}

/// A memory capsule that has opened.
///
/// This used to carry no link at all, so whoever received it had a sentence
/// about a thing they could not go and look at.
ShareMessage memoryOpened({
  required String title,
  required int wishCount,
  required String slug,
  String? senderName,
}) {
  final from = _from(senderName);
  final who = from == null ? 'is now open' : 'from $from is now open';
  final wishes = wishCount == 1 ? '1 wish' : '$wishCount wishes';
  return ShareMessage(
    text: '$title $who — $wishes inside.',
    url: AppLinks.memoryInvite(slug),
  );
}

/// A person, so a friend can find them.
///
/// The link is the app itself, not the person: a profile has no public web
/// page and `/people/:id` is not one of the paths the app claims, so a link
/// to it would open nothing. The handle in the text is what the reader
/// actually searches for once they are in.
ShareMessage person({required String handle, String? senderName}) {
  final from = _from(senderName);
  return ShareMessage(
    text: from == null
        ? 'Find $handle on Wishtick'
        : '$from thinks you should find $handle on Wishtick',
    url: AppLinks.origin,
  );
}

/// An invitation to the app itself, for somebody with no account yet.
ShareMessage joinWishtick({String? senderName}) {
  final from = _from(senderName);
  return ShareMessage(
    text: from == null
        ? 'Join me on Wishtick — keep a wishlist so the people who love you '
              'know what to gift.'
        : 'Join $from on Wishtick — keep a wishlist so the people who love '
              'you know what to gift.',
    url: AppLinks.origin,
  );
}
