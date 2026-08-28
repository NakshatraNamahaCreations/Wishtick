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
  List<String> contributors = const [],
  List<MemoryWish> wishes = const [],
  bool isHost = true,
  String? coverUrl,
  String? description = 'Join us as we make this birthday unforgettable.',
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
  contributors: contributors,
  hostId: 'user_1',
  isHost: isHost,
  includeYear: false,
  createdAt: DateTime.utc(2026, 7, 1),
  wishes: wishes,
  description: description,
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
    String? description,
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
      'description': description,
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
    String? description,
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

  @override
  Future<void> removeWish(String capsuleId, String wishId) async {}

  @override
  Future<int> react(String capsuleId, String wishId) async {
    reactCalls.add(wishId);
    return 1;
  }
}
