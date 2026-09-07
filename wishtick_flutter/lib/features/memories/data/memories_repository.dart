import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/memory.dart';

/// Memory capsules: create, contribute, and open.
///
/// Every read here returns the same [MemoryCapsule] shape whether the capsule
/// is sealed or open — `wishes` is simply empty until it opens. The client does
/// not decide that; the server withholds the content.
class MemoriesRepository {
  MemoriesRepository(this._api);

  final ApiClient _api;

  // ── Capsules ────────────────────────────────────────────────────────────

  /// "Created By You" (`4104:1433`).
  Future<List<MemoryCapsule>> listMine() async {
    final json = await _api.get<List<dynamic>>('/memories/mine');
    return json
        .map((e) => MemoryCapsule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// "Contributed By You" (`4104:1433`).
  Future<List<MemoryCapsule>> listContributed() async {
    final json = await _api.get<List<dynamic>>('/memories/contributed');
    return json
        .map((e) => MemoryCapsule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MemoryCapsule> get(String id) async {
    final json = await _api.get<Map<String, dynamic>>('/memories/$id');
    return MemoryCapsule.fromJson(json);
  }

  /// Creates a capsule for a WishMate.
  ///
  /// [recipientUserId], not a typed name: the server refuses a recipient the
  /// caller is not linked to, and being a real account is what lets the capsule
  /// reach them when it opens.
  /// "For You" — unlocked capsules somebody made about the caller.
  ///
  /// Only the opened ones: a sealed capsule is a surprise, and the server keeps
  /// it out of this list rather than trusting the client not to draw it.
  Future<List<MemoryCapsule>> listForMe() async {
    final json = await _api.get<List<dynamic>>('/memories/for-me');
    return json
        .map((e) => MemoryCapsule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

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
    final json = await _api.post<Map<String, dynamic>>(
      '/memories',
      body: {
        'title': title,
        'recipientUserId': recipientUserId,
        'occasion': occasion,
        'unlockAt': unlockAt.toUtc().toIso8601String(),
        'timezone': timezone,
        'relation': ?relation,
        'occasionDate': ?occasionDate?.toUtc().toIso8601String(),
        'includeYear': ?includeYear,
        'coverMediaId': ?coverMediaId,
      },
    );
    return MemoryCapsule.fromJson(json);
  }

  /// Moving `unlockAt` reschedules the unlock job — the server does that.
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
  }) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/memories/$id',
      body: {
        'title': ?title,
        'occasion': ?occasion,
        'unlockAt': ?unlockAt?.toUtc().toIso8601String(),
        'timezone': ?timezone,
        'relation': ?relation,
        'occasionDate': ?occasionDate?.toUtc().toIso8601String(),
        'includeYear': ?includeYear,
        'coverMediaId': ?coverMediaId,
      },
    );
    return MemoryCapsule.fromJson(json);
  }

  Future<void> remove(String id) => _api.delete<void>('/memories/$id');

  /// Opens it now, ahead of its instant. Host only.
  Future<MemoryCapsule> unlockNow(String id) async {
    final json = await _api.post<Map<String, dynamic>>('/memories/$id/unlock');
    return MemoryCapsule.fromJson(json);
  }

  // ── Wishes ──────────────────────────────────────────────────────────────

  /// Adds a wish. [mediaId] is required for every kind but text.
  Future<MemoryWish> addWish(
    String capsuleId, {
    required MemoryWishKind kind,
    String? text,
    String? mediaId,
    String? contributorName,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/memories/$capsuleId/wishes',
      body: {
        'kind': kind.wireValue,
        'text': ?text,
        'mediaId': ?mediaId,
        'contributorName': ?contributorName,
      },
    );
    return MemoryWish.fromJson(json);
  }

  /// The caller's own wishes, readable whether or not the capsule has opened.
  ///
  /// Not subject to the time-lock: showing somebody the words they wrote
  /// themselves reveals nothing about anyone else. This is what the host gets
  /// instead of the old "Open it now", which forced the capsule open for
  /// everybody and could not be undone.
  Future<List<MemoryWish>> myWishes(String capsuleId) async {
    final json = await _api.get<List<dynamic>>(
      '/memories/$capsuleId/wishes/mine',
    );
    return json
        .map((e) => MemoryWish.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The wishes inside.
  ///
  /// Answers 409 `MEMORY_LOCKED` while the capsule is sealed rather than an
  /// empty list — the caller must not present "locked" as "empty".
  Future<List<MemoryWish>> wishes(String capsuleId) async {
    final json = await _api.get<List<dynamic>>('/memories/$capsuleId/wishes');
    return json
        .map((e) => MemoryWish.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> removeWish(String capsuleId, String wishId) =>
      _api.delete<void>('/memories/$capsuleId/wishes/$wishId');

  /// "React" on the story viewer (`2078:357`).
  Future<int> react(String capsuleId, String wishId) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/memories/$capsuleId/wishes/$wishId/react',
    );
    return json['reactionCount'] as int? ?? 0;
  }

  // ── Replies ─────────────────────────────────────────────────────────────

  /// Everyone who has sent the caller a memory, across all their opened ones.
  ///
  /// The only source of a legal addressee — the server refuses anyone absent
  /// from it, so a reply cannot become a way to message an arbitrary account.
  Future<List<ReplyAudienceEntry>> replyAudience() async {
    final json = await _api.get<List<dynamic>>('/memories/reply-audience');
    return json
        .map((e) => ReplyAudienceEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sends one reply to everyone named. [mediaId] is required for every kind
  /// but text, and must have been uploaded with the `memory_reply` purpose.
  Future<MemoryReply> sendReply({
    required MemoryWishKind kind,
    required List<String> recipientIds,
    String? text,
    String? mediaId,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/memories/replies',
      body: {
        'kind': kind.wireValue,
        'recipientIds': recipientIds,
        'text': ?text,
        'mediaId': ?mediaId,
      },
    );
    return MemoryReply.fromJson(json);
  }

  /// The replies on one memory that the caller may see.
  ///
  /// Empty rather than an error for someone with no part in the capsule: this
  /// hangs off a screen anyone signed in can open, and a 403 here would be a
  /// side channel telling them a reply exists.
  Future<List<MemoryReply>> replies(String capsuleId) async {
    final json = await _api.get<List<dynamic>>('/memories/$capsuleId/replies');
    return json
        .map((e) => MemoryReply.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The author withdrawing their own reply. It vanishes for every recipient.
  Future<void> removeReply(String replyId) =>
      _api.delete<void>('/memories/replies/$replyId');
}

final memoriesRepositoryProvider = Provider<MemoriesRepository>((ref) {
  return MemoriesRepository(ref.watch(apiClientProvider));
});
