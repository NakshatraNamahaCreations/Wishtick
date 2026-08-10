import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/group_gift/domain/group_gift.dart';
import 'package:wishtick_flutter/features/group_gift/domain/settlement.dart';

void main() {
  group('GroupGift.fromJson', () {
    test('reads the whole detail view', () {
      final gift = GroupGift.fromJson({
        'id': 'gg_1',
        'itemId': 'item_1',
        'wishlistId': 'wl_1',
        'status': 'open',
        'title': "Siya's birthday gift",
        'hostId': 'host_1',
        'hostUpiId': 'rohanr1@okaxis',
        'contributionMode': 'custom',
        'suggestedAmountsMinor': [50000, 100000],
        'targetAmountMinor': 1734700,
        'chargesTotalMinor': 34800,
        'charges': [
          {
            'id': 'c1',
            'label': 'Delivery Charges',
            'amountMinor': 19900,
            'addedBy': 'host_1',
            'addedAt': '2026-08-01T00:00:00.000Z',
          },
        ],
        'lines': const [],
        'items': [
          {
            'lineId': null,
            'itemId': 'item_1',
            'title': 'Michael Kors Women Handbag',
            'imageUrl': 'https://example.test/bag.png',
            'amountMinor': 1699900,
            'removable': false,
          },
        ],
        'collectedAmountMinor': 0,
        'currency': 'INR',
        'percentFunded': 0,
        'contributorCount': 0,
        'participantCount': 0,
        'participants': const [],
        'recentContributions': const [],
        'myContributionMinor': 0,
        'createdAt': '2026-08-01T00:00:00.000Z',
      });

      expect(gift.hostId, 'host_1');
      expect(gift.contributionMode, ContributionMode.custom);
      expect(gift.items.single.removable, isFalse);
      expect(gift.charges.single.label, 'Delivery Charges');
      // The Grand Total minus its charges — the summary's "Total Gift Price".
      expect(gift.giftsTotalMinor, 1699900);
    });

    test('a list-view payload survives the missing detail fields', () {
      final gift = GroupGift.fromJson({
        'id': 'gg_1',
        'itemId': 'item_1',
        'wishlistId': 'wl_1',
        'status': 'open',
        'title': 'x',
        'hostId': 'host_1',
        'targetAmountMinor': 1600000,
        'collectedAmountMinor': 1440000,
        'currency': 'INR',
        'percentFunded': 90,
        'contributorCount': 6,
        'myContributionMinor': 0,
        'createdAt': '2026-08-01T00:00:00.000Z',
      });

      expect(gift.items, isEmpty);
      expect(gift.charges, isEmpty);
      expect(gift.suggestedAmountsMinor, isEmpty);
    });

    test('canManage follows the share block, which only the host gets', () {
      final json = {
        'id': 'gg_1',
        'itemId': 'i',
        'wishlistId': 'w',
        'status': 'open',
        'title': 'x',
        'hostId': 'host_1',
        'targetAmountMinor': 1,
        'collectedAmountMinor': 0,
        'currency': 'INR',
        'percentFunded': 0,
        'contributorCount': 0,
        'myContributionMinor': 0,
        'createdAt': '2026-08-01T00:00:00.000Z',
      };

      expect(GroupGift.fromJson(json).canManage, isFalse);
      expect(
        GroupGift.fromJson({
          ...json,
          'share': {'slug': 's', 'url': 'u', 'hasPasscode': false},
        }).canManage,
        isTrue,
      );
    });
  });

  group('Settlement sides', () {
    // A settlement has two sides and each sees a different screen, so getting
    // this backwards would show the payer's "Mark as Sent" to the receiver.
    test('on a return, the host pays and the contributor receives', () {
      final row = Settlement(
        id: 'st_1',
        groupGiftId: 'gg_1',
        contributorId: 'user_2',
        hostId: 'host_1',
        direction: SettlementDirection.returnToContributors,
        amountMinor: 33300,
        currency: 'INR',
        status: SettlementStatus.pending,
        createdAt: DateTime(2026, 8, 1),
      );

      expect(row.amPayer('host_1'), isTrue);
      expect(row.amPayer('user_2'), isFalse);
      expect(row.counterpartId('host_1'), 'user_2');
      expect(row.counterpartId('user_2'), 'host_1');
    });

    test('on a top-up, it is the other way round', () {
      final row = Settlement(
        id: 'st_1',
        groupGiftId: 'gg_1',
        contributorId: 'user_2',
        hostId: 'host_1',
        direction: SettlementDirection.topUp,
        amountMinor: 33300,
        currency: 'INR',
        status: SettlementStatus.pending,
        createdAt: DateTime(2026, 8, 1),
      );

      expect(row.amPayer('user_2'), isTrue);
      expect(row.amPayer('host_1'), isFalse);
    });

    test('only pending and sent count as still owing', () {
      expect(SettlementStatus.pending.isOpen, isTrue);
      expect(SettlementStatus.sent.isOpen, isTrue);
      expect(SettlementStatus.confirmed.isOpen, isFalse);
      expect(SettlementStatus.cancelled.isOpen, isFalse);
    });

    test('an unknown direction does not silently become a return', () {
      expect(SettlementDirection.fromWire('nonsense'), isNull);
      expect(SettlementDirection.fromWire(null), isNull);
      expect(
        SettlementDirection.fromWire('top_up'),
        SettlementDirection.topUp,
      );
    });
  });

  group('GroupGiftBalance', () {
    test('a surplus is positive and owed back by the host', () {
      final balance = GroupGiftBalance.fromJson({
        'totalCostMinor': 1734700,
        'pledgedMinor': 1934700,
        'collectedMinor': 1934700,
        'differenceMinor': 200000,
        'direction': 'return',
        'contributorCount': 6,
      });

      expect(balance.isSquare, isFalse);
      expect(balance.absoluteDifferenceMinor, 200000);
      expect(balance.direction, SettlementDirection.returnToContributors);
    });

    test('a shortfall is negative but still asks for a positive amount', () {
      final balance = GroupGiftBalance.fromJson({
        'totalCostMinor': 1934700,
        'pledgedMinor': 1734700,
        'collectedMinor': 1734700,
        'differenceMinor': -200000,
        'direction': 'top_up',
        'contributorCount': 6,
      });

      expect(balance.absoluteDifferenceMinor, 200000);
      expect(balance.direction, SettlementDirection.topUp);
    });

    test('square means no direction at all', () {
      final balance = GroupGiftBalance.fromJson({
        'totalCostMinor': 1734700,
        'pledgedMinor': 1734700,
        'collectedMinor': 1734700,
        'differenceMinor': 0,
        'direction': null,
        'contributorCount': 6,
      });

      expect(balance.isSquare, isTrue);
      expect(balance.direction, isNull);
    });
  });
}
