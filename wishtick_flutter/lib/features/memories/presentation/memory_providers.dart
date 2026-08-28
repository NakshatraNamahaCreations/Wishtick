import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/memories_repository.dart';
import '../domain/memory.dart';

/// "Created By You" (`4104:1433`).
final myMemoriesProvider = FutureProvider.autoDispose<List<MemoryCapsule>>(
  (ref) => ref.watch(memoriesRepositoryProvider).listMine(),
);

/// "For You" — unlocked capsules somebody made *about* the signed-in user.
///
/// Sealed ones are deliberately absent: the server withholds them, because
/// listing a capsule before it opens would tell its recipient both that it
/// exists and who is building it.
final memoriesForMeProvider = FutureProvider.autoDispose<List<MemoryCapsule>>(
  (ref) => ref.watch(memoriesRepositoryProvider).listForMe(),
);

/// "Contributed By You" (`4104:1433`).
final contributedMemoriesProvider =
    FutureProvider.autoDispose<List<MemoryCapsule>>(
      (ref) => ref.watch(memoriesRepositoryProvider).listContributed(),
    );

/// One capsule, by id. Keyed by a plain String — anything without value
/// equality in a family key refetches forever.
final memoryProvider = FutureProvider.autoDispose.family<MemoryCapsule, String>(
  (ref, id) => ref.watch(memoriesRepositoryProvider).get(id),
);

/// The capsules already open, newest first — the "Unlocked Memories" row.
final unlockedMemoriesProvider =
    FutureProvider.autoDispose<List<MemoryCapsule>>((ref) async {
      final mine = await ref.watch(myMemoriesProvider.future);
      final contributed = await ref.watch(contributedMemoriesProvider.future);
      final all = [...mine, ...contributed].where((m) => m.isOpen).toList()
        ..sort((a, b) => b.unlockAt.compareTo(a.unlockAt));
      return all;
    });

/// Everything still sealed, soonest first — "Upcoming Unlocks".
final upcomingMemoriesProvider =
    FutureProvider.autoDispose<List<MemoryCapsule>>((ref) async {
      final mine = await ref.watch(myMemoriesProvider.future);
      final contributed = await ref.watch(contributedMemoriesProvider.future);
      final all = [...mine, ...contributed].where((m) => !m.isOpen).toList()
        ..sort((a, b) => a.unlockAt.compareTo(b.unlockAt));
      return all;
    });
