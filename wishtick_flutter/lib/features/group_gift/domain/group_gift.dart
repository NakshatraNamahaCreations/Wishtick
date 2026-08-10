import 'package:flutter/foundation.dart';

/// Lifecycle of a group gift, mirroring the backend's `GroupGiftStatus`.
enum GroupGiftStatus {
  open('open'),
  funded('funded'),
  purchasing('purchasing'),
  purchased('purchased'),
  fulfilled('fulfilled'),
  cancelled('cancelled'),
  refunding('refunding');

  const GroupGiftStatus(this.wireValue);

  final String wireValue;

  static GroupGiftStatus fromWire(String? value) => GroupGiftStatus.values
      .firstWhere((v) => v.wireValue == value, orElse: () => open);

  /// Only an open gift can still take money.
  bool get acceptsContributions => this == open;
}

/// How the host suggests the bill be divided (`299:1658`).
///
/// Advisory only. The server accepts any amount in either mode — a group that
/// rejects ₹400 from someone asked for ₹500 helps nobody — so this drives what
/// the contribute sheet *proposes*, never what it permits.
enum ContributionMode {
  equal('equal'),
  custom('custom');

  const ContributionMode(this.wireValue);

  final String wireValue;

  static ContributionMode fromWire(String? value) => ContributionMode.values
      .firstWhere((v) => v.wireValue == value, orElse: () => equal);
}

/// A non-item cost folded into the bill — delivery, packaging (`4007:568`).
@immutable
class GroupGiftCharge {
  const GroupGiftCharge({
    required this.id,
    required this.label,
    required this.amountMinor,
    required this.addedBy,
    required this.addedAt,
  });

  final String id;
  final String label;
  final int amountMinor;
  final String addedBy;
  final DateTime addedAt;

  factory GroupGiftCharge.fromJson(Map<String, dynamic> json) =>
      GroupGiftCharge(
        id: json['id'] as String,
        label: json['label'] as String,
        amountMinor: json['amountMinor'] as int? ?? 0,
        addedBy: json['addedBy'] as String? ?? '',
        addedAt: DateTime.parse(json['addedAt'] as String),
      );
}

/// An item beyond the primary one (`4007:720` → `4007:801`).
@immutable
class GroupGiftLine {
  const GroupGiftLine({
    required this.id,
    required this.itemId,
    required this.addedAt,
    this.amountMinor,
  });

  final String id;
  final String itemId;

  /// Null when the item carries no price — the summary shows a dash rather
  /// than inventing a zero, and the total quietly excludes it.
  final int? amountMinor;
  final DateTime addedAt;

  factory GroupGiftLine.fromJson(Map<String, dynamic> json) => GroupGiftLine(
    id: json['id'] as String,
    itemId: json['itemId'] as String,
    amountMinor: json['amountMinor'] as int?,
    addedAt: DateTime.parse(json['addedAt'] as String),
  );
}

/// One row of "Selected Gifts (N)" (`4007:801`) — everything that screen
/// draws, already ordered primary-first by the server.
@immutable
class GroupGiftItem {
  const GroupGiftItem({
    required this.itemId,
    required this.title,
    required this.removable,
    this.lineId,
    this.imageUrl,
    this.amountMinor,
  });

  /// The line id, or null for the primary item — which has no line.
  final String? lineId;

  final String itemId;
  final String title;
  final String? imageUrl;
  final int? amountMinor;

  /// False for the primary item: dropping it would leave a group gift for
  /// nothing, so the design offers cancel instead and shows the × on the
  /// extras only.
  final bool removable;

  factory GroupGiftItem.fromJson(Map<String, dynamic> json) => GroupGiftItem(
    lineId: json['lineId'] as String?,
    itemId: json['itemId'] as String,
    title: json['title'] as String? ?? '',
    imageUrl: json['imageUrl'] as String?,
    amountMinor: json['amountMinor'] as int?,
    removable: json['removable'] as bool? ?? false,
  );
}

/// A named member. Anonymous contributors never appear in this list.
@immutable
class GroupGiftParticipant {
  const GroupGiftParticipant({required this.userId, required this.name});

  final String userId;
  final String name;

  factory GroupGiftParticipant.fromJson(Map<String, dynamic> json) =>
      GroupGiftParticipant(
        userId: json['userId'] as String,
        name: json['name'] as String? ?? 'A friend',
      );
}

/// One entry on the contribution timeline.
@immutable
class GroupGiftContribution {
  const GroupGiftContribution({
    required this.id,
    required this.amountMinor,
    required this.anonymous,
    required this.createdAt,
    this.message,
    this.contributor,
  });

  final String id;
  final int amountMinor;
  final bool anonymous;
  final DateTime createdAt;
  final String? message;

  /// Null when the contribution was anonymous. The server withholds the
  /// identity rather than sending it with a flag, so there is nothing here to
  /// leak by rendering the wrong field.
  final GroupGiftParticipant? contributor;

  factory GroupGiftContribution.fromJson(Map<String, dynamic> json) =>
      GroupGiftContribution(
        id: json['id'] as String,
        amountMinor: json['amountMinor'] as int? ?? 0,
        anonymous: json['anonymous'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        message: json['message'] as String?,
        contributor: json['contributor'] == null
            ? null
            : GroupGiftParticipant.fromJson(
                json['contributor'] as Map<String, dynamic>,
              ),
      );
}

/// The public share link. Present only for the host.
@immutable
class GroupGiftShare {
  const GroupGiftShare({
    required this.slug,
    required this.url,
    required this.hasPasscode,
    this.expiresAt,
  });

  final String slug;
  final String url;
  final bool hasPasscode;
  final DateTime? expiresAt;

  factory GroupGiftShare.fromJson(Map<String, dynamic> json) => GroupGiftShare(
    slug: json['slug'] as String,
    url: json['url'] as String,
    hasPasscode: json['hasPasscode'] as bool? ?? false,
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.parse(json['expiresAt'] as String),
  );
}

/// A group gift, as `GET /group-gifts/:id` and `/group-gifts/mine` return it.
///
/// One model serves both Home's read-only chip-in card and the full detail
/// screens: the list view is a strict subset of the detail view, so splitting
/// them would only create two shapes to keep in step.
@immutable
class GroupGift {
  const GroupGift({
    required this.id,
    required this.itemId,
    required this.wishlistId,
    required this.status,
    required this.title,
    required this.hostId,
    required this.targetAmountMinor,
    required this.collectedAmountMinor,
    required this.currency,
    required this.percentFunded,
    required this.contributorCount,
    required this.myContributionMinor,
    required this.createdAt,
    // Defaulted rather than required: these are the detail view's extras, and
    // the list endpoint's callers should not have to spell out six empty
    // collections to build a card that shows none of them.
    this.contributionMode = ContributionMode.equal,
    this.suggestedAmountsMinor = const [],
    this.chargesTotalMinor = 0,
    this.charges = const [],
    this.lines = const [],
    this.items = const [],
    this.participantCount = 0,
    this.participants = const [],
    this.recentContributions = const [],
    this.hostUpiId,
    this.deadline,
    this.message,
    this.ogImageUrl,
    this.chatId,
    this.recipientName,
    this.thankYouNote,
    this.thankYouAt,
    this.share,
  });

  final String id;
  final String itemId;
  final String wishlistId;
  final GroupGiftStatus status;

  /// The host's name for it, e.g. "Siya's birthday gift".
  final String title;

  /// Who started it — the participant list badges them "Host" (`316:536`).
  /// [canManage] answers the same question for *the caller*; this answers it
  /// for everyone.
  final String hostId;

  /// Where members send their share. Wishtick never holds the money — it is
  /// collected in the host's own account (`299:1658`).
  final String? hostUpiId;

  final ContributionMode contributionMode;

  /// The ₹500 / ₹1,000 / ₹2,000 chips the host offers, in minor units.
  final List<int> suggestedAmountsMinor;

  /// The Grand Total — every gift plus every charge. What the group collects.
  ///
  /// Server-derived from the lines and charges, never set by hand, so this can
  /// never disagree with the breakdown that justifies it.
  final int targetAmountMinor;

  /// The charges' share of [targetAmountMinor], so the summary need not re-add
  /// them to show a "Total Charges" row.
  final int chargesTotalMinor;

  final List<GroupGiftCharge> charges;
  final List<GroupGiftLine> lines;

  /// "Selected Gifts (N)" — the primary item first, then the extras.
  final List<GroupGiftItem> items;

  final int collectedAmountMinor;
  final String currency;

  /// Server-computed and clamped 0..100 — not re-derived here, so the bar and
  /// the label can never disagree.
  final int percentFunded;

  final int contributorCount;
  final int participantCount;
  final List<GroupGiftParticipant> participants;
  final List<GroupGiftContribution> recentContributions;
  final int myContributionMinor;
  final DateTime createdAt;
  final DateTime? deadline;
  final String? message;
  final String? ogImageUrl;
  final String? chatId;

  /// Who the gift is for. Signs the thank-you card (`2219:603`).
  final String? recipientName;

  /// The recipient's thank-you note (`2219:603`), once written. Authored by the
  /// person the gift was for — not the host.
  final String? thankYouNote;
  final DateTime? thankYouAt;

  bool get hasThankYou => (thankYouNote?.trim().isNotEmpty ?? false);

  /// Present only when the caller is the host.
  final GroupGiftShare? share;

  bool get hasContributed => myContributionMinor > 0;

  /// The host is the only one who can edit the bill or raise settlements, and
  /// [share] is the only field the server gates on that — so its presence *is*
  /// the capability, rather than a role guess made on the client.
  bool get canManage => share != null;

  /// Whether the bill — gifts and charges — can still be changed.
  ///
  /// Mirrors the server's `assertBillEditable`: frozen the moment anyone
  /// contributes, because changing the target afterwards moves the goalposts
  /// under people who already committed against the old number.
  bool get billEditable =>
      status == GroupGiftStatus.open &&
      contributorCount == 0 &&
      collectedAmountMinor == 0;

  /// Every gift's share of the bill — the "Total Gift Price" row on `4006:463`.
  int get giftsTotalMinor => targetAmountMinor - chargesTotalMinor;

  /// Whole days until the deadline; null when the gift has none.
  int? daysToDeadline({DateTime? now}) {
    final end = deadline;
    if (end == null) return null;
    final today = now ?? DateTime.now();
    return DateTime(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  factory GroupGift.fromJson(Map<String, dynamic> json) => GroupGift(
    id: json['id'] as String,
    itemId: json['itemId'] as String,
    wishlistId: json['wishlistId'] as String,
    status: GroupGiftStatus.fromWire(json['status'] as String?),
    title: json['title'] as String? ?? '',
    hostId: json['hostId'] as String? ?? '',
    hostUpiId: json['hostUpiId'] as String?,
    contributionMode: ContributionMode.fromWire(
      json['contributionMode'] as String?,
    ),
    suggestedAmountsMinor:
        (json['suggestedAmountsMinor'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        const [],
    targetAmountMinor: json['targetAmountMinor'] as int? ?? 0,
    chargesTotalMinor: json['chargesTotalMinor'] as int? ?? 0,
    charges:
        (json['charges'] as List<dynamic>?)
            ?.map((e) => GroupGiftCharge.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    lines:
        (json['lines'] as List<dynamic>?)
            ?.map((e) => GroupGiftLine.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    items:
        (json['items'] as List<dynamic>?)
            ?.map((e) => GroupGiftItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    collectedAmountMinor: json['collectedAmountMinor'] as int? ?? 0,
    currency: json['currency'] as String? ?? 'INR',
    percentFunded: json['percentFunded'] as int? ?? 0,
    contributorCount: json['contributorCount'] as int? ?? 0,
    participantCount: json['participantCount'] as int? ?? 0,
    participants:
        (json['participants'] as List<dynamic>?)
            ?.map(
              (e) => GroupGiftParticipant.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        const [],
    recentContributions:
        (json['recentContributions'] as List<dynamic>?)
            ?.map(
              (e) => GroupGiftContribution.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        const [],
    myContributionMinor: json['myContributionMinor'] as int? ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    deadline: json['deadline'] == null
        ? null
        : DateTime.parse(json['deadline'] as String),
    message: json['message'] as String?,
    ogImageUrl: json['ogImageUrl'] as String?,
    chatId: json['chatId'] as String?,
    recipientName: json['recipientName'] as String?,
    thankYouNote: json['thankYouNote'] as String?,
    thankYouAt: json['thankYouAt'] == null
        ? null
        : DateTime.parse(json['thankYouAt'] as String),
    share: json['share'] == null
        ? null
        : GroupGiftShare.fromJson(json['share'] as Map<String, dynamic>),
  );
}
