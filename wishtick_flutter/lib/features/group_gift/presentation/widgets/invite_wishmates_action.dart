import 'package:flutter/material.dart';

import '../../../wishmates/presentation/widgets/quick_share_sheet.dart';

/// Asks WishMates to chip in, from wherever the app offers it.
///
/// One implementation rather than one per screen: "Invite Friends" on the
/// created screen and "Invite Friends & Family" on the participants list are
/// the same action, and the second was still copying a link long after the
/// first stopped.
///
/// A picker rather than a link. A group gift hangs off a wishlist, and on a
/// private one a link-holder cannot gift at all — the person who followed it
/// would land on a 404. An invitation is answerable, and accepting it grants
/// the access that joining needs.
Future<void> inviteWishmatesToGroupGift(
  BuildContext context, {
  required String groupGiftId,
  required String title,
  String? shareUrl,
}) => showQuickShareSheet(
  context,
  GroupGiftShareTarget(groupGiftId: groupGiftId, title: title, url: shareUrl),
);
