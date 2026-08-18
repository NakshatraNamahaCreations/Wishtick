import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gifting_repository.dart';
import '../domain/gift_list_item.dart';

/// Which of the three Profile list screens to read.
enum GiftListKind { received, given, onHold }

/// The rows behind Gifts Received / Given / On Hold.
///
/// Family-keyed on the enum so the three screens share one provider and one
/// card widget — they differ only in which endpoint they read and what the
/// counterparty line says.
final giftListProvider =
    FutureProvider.family<List<GiftListItem>, GiftListKind>((ref, kind) {
      final repo = ref.watch(giftingRepositoryProvider);
      return switch (kind) {
        GiftListKind.received => repo.listReceived(),
        GiftListKind.given => repo.listGiven(),
        GiftListKind.onHold => repo.listOnHold(),
      };
    });
