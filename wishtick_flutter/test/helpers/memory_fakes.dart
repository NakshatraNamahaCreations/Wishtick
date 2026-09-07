import 'package:wishtick_flutter/features/memories/data/memories_repository.dart';
import 'package:wishtick_flutter/features/memories/domain/memory.dart';
import 'package:wishtick_flutter/features/wishmates/domain/wishmate.dart';

MemoryWish buildWish({
  required String id,
  required String contributorName,
  MemoryWishKind kind = MemoryWishKind.text,
  String? text = 'Happy Birthday!',
  String? mediaUrl,
  int durationMs = 0,
  int reactionCount = 0,
}) => MemoryWish(
  id: id,
  contributorName: contributorName,
  kind: kind,
  text: text,
  mediaUrl: mediaUrl,
  durationMs: durationMs,
  reactionCount: reactionCount,
  createdAt: DateTime.utc(2026, 7, 1),
);

MemoryCapsule buildCapsule({
  String id = 'mem_1',
  String title = "Mridula's Birthday",
  String personName = 'Mridula',
  PersonIdentity? person,
  MemoryStatus status = MemoryStatus.collecting,
  DateTime? unlockAt,
  int wishCount = 0,
  int myWishCount = 0,
  List<String> contributors = const [],
  List<MemoryWish> wishes = const [],
  bool isHost = true,
  bool isRecipient = false,
  String? coverUrl,
}) => MemoryCapsule(
  id: id,
  title: title,
  personName: personName,
  person:
      person ??
      PersonIdentity(
        userId: 'u_recipient',
        username: 'mridula',
        displayName: personName,
        photoUrl: null,
        online: false,
        lastSeenAt: null,
      ),
  occasion: 'birthday',
  status: status,
  // Far enough out that the countdown label is stable across a slow test run.
  unlockAt: unlockAt ?? DateTime.now().add(const Duration(days: 5, hours: 2)),
  timezone: 'Asia/Kolkata',
  wishCount: wishCount,
  myWishCount: myWishCount,
  contributors: contributors,
  hostId: 'user_1',
  isHost: isHost,
  isRecipient: isRecipient,
  includeYear: false,
  createdAt: DateTime.utc(2026, 7, 1),
  wishes: wishes,
  coverUrl: coverUrl,
  share: isHost
      ? const MemoryShare(slug: 'abc123', url: 'https://wt.test/m/abc123')
      : null,
);

class FakeMemoriesRepository implements MemoriesRepository {
  FakeMemoriesRepository({
    List<MemoryCapsule>? mine,
    List<MemoryCapsule>? contributed,
  }) : mine = mine ?? [],
       contributed = contributed ?? [];

  List<MemoryCapsule> mine;
  List<MemoryCapsule> contributed;

  Object? failure;

  final createCalls = <Map<String, Object?>>[];
  final addWishCalls = <Map<String, Object?>>[];
  final unlockCalls = <String>[];
  final reactCalls = <String>[];

  void _maybeThrow() {
    final f = failure;
    if (f != null) throw f;
  }

  MemoryCapsule _byId(String id) =>
      [...mine, ...contributed].firstWhere((m) => m.id == id);

  @override
  Future<List<MemoryCapsule>> listMine() async => mine;

  @override
  Future<List<MemoryCapsule>> listContributed() async => contributed;

  @override
  Future<MemoryCapsule> get(String id) async => _byId(id);

  /// Capsules somebody made about this user, for the "For You" rail.
  List<MemoryCapsule> forMe = const [];

  @override
  Future<List<MemoryCapsule>> listForMe() async {
    _maybeThrow();
    return forMe;
  }

  @override
  Future<MemoryCapsule> create({
    required String title,
    required String recipientUserId,
    required String occasion,
    required DateTime unlockAt,
    required String timezone,
    String? relation,
    DateTime? occasionDate,
    bool? includeYear,
    String? coverMediaId,
  }) async {
    _maybeThrow();
    createCalls.add({
      'title': title,
      'recipientUserId': recipientUserId,
      'occasion': occasion,
      'unlockAt': unlockAt,
      'timezone': timezone,
      'relation': relation,
      'occasionDate': occasionDate,
      'includeYear': includeYear,
      'coverMediaId': coverMediaId,
    });
    return buildCapsule(id: 'mem_new', title: title);
  }

  @override
  Future<MemoryCapsule> update(
    String id, {
    String? title,
    String? occasion,
    DateTime? unlockAt,
    String? timezone,
    String? relation,
    DateTime? occasionDate,
    bool? includeYear,
    String? coverMediaId,
  }) async => _byId(id);

  @override
  Future<void> remove(String id) async {}

  @override
  Future<MemoryCapsule> unlockNow(String id) async {
    unlockCalls.add(id);
    return _byId(id);
  }

  @override
  Future<MemoryWish> addWish(
    String capsuleId, {
    required MemoryWishKind kind,
    String? text,
    String? mediaId,
    String? contributorName,
  }) async {
    _maybeThrow();
    addWishCalls.add({
      'capsuleId': capsuleId,
      'kind': kind,
      'text': text,
      'mediaId': mediaId,
    });
    return buildWish(
      id: 'wish_new',
      contributorName: 'Priya',
      kind: kind,
      text: text,
    );
  }

  @override
  Future<List<MemoryWish>> wishes(String capsuleId) async =>
      _byId(capsuleId).wishes;

  /// What `myWishes` answers. Set it to exercise the sealed-capsule preview,
  /// which is the one read the time-lock deliberately does not cover.
  List<MemoryWish> ownWishes = [];

  @override
  Future<List<MemoryWish>> myWishes(String capsuleId) async => ownWishes;

  @override
  Future<void> removeWish(String capsuleId, String wishId) async {}

  @override
  Future<int> react(String capsuleId, String wishId) async {
    reactCalls.add(wishId);
    return 1;
  }

  // ── Replies ─────────────────────────────────────────────────────────────

  /// Who `replyAudience` answers with.
  List<ReplyAudienceEntry> audience = [];

  /// What `replies` answers with, for every capsule.
  List<MemoryReply> repliesOnCapsule = [];

  final sendReplyCalls = <Map<String, Object?>>[];
  final removedReplies = <String>[];

  @override
  Future<List<ReplyAudienceEntry>> replyAudience() async {
    _maybeThrow();
    return audience;
  }

  @override
  Future<MemoryReply> sendReply({
    required MemoryWishKind kind,
    required List<String> recipientIds,
    String? text,
    String? mediaId,
  }) async {
    _maybeThrow();
    sendReplyCalls.add({
      'kind': kind,
      'recipientIds': recipientIds,
      'text': text,
      'mediaId': mediaId,
    });
    return buildReply(
      id: 'reply_new',
      kind: kind,
      text: text,
      recipientCount: recipientIds.length,
      isMine: true,
    );
  }

  @override
  Future<List<MemoryReply>> replies(String capsuleId) async => repliesOnCapsule;

  @override
  Future<void> removeReply(String replyId) async => removedReplies.add(replyId);
}

MemoryReply buildReply({
  required String id,
  String authorName = 'Ananya',
  MemoryWishKind kind = MemoryWishKind.text,
  String? text = 'Thank you all!',
  String? mediaUrl,
  int recipientCount = 1,
  bool isMine = false,
}) => MemoryReply(
  id: id,
  authorName: authorName,
  kind: kind,
  text: text,
  mediaUrl: mediaUrl,
  durationMs: 0,
  recipientCount: recipientCount,
  isMine: isMine,
  createdAt: DateTime.utc(2026, 7, 20),
);

ReplyAudienceEntry buildAudienceEntry({
  required String userId,
  String displayName = 'Jayanth',
  bool isHost = true,
  String capsuleId = 'm1',
  String capsuleTitle = "Ananya's Birthday",
}) => ReplyAudienceEntry(
  person: PersonIdentity(
    userId: userId,
    username: displayName.toLowerCase(),
    displayName: displayName,
    photoUrl: null,
    online: false,
    lastSeenAt: null,
  ),
  isHost: isHost,
  capsuleId: capsuleId,
  capsuleTitle: capsuleTitle,
);
