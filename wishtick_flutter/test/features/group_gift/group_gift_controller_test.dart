import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/group_gift/data/group_gift_repository.dart';
import 'package:wishtick_flutter/features/group_gift/domain/group_gift.dart';
import 'package:wishtick_flutter/features/group_gift/domain/settlement.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/create_group_gift_controller.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/group_gift_controller.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/settlement_controller.dart';

import '../../helpers/group_gift_fakes.dart';

void main() {
  late FakeGroupGiftRepository repo;
  late ProviderContainer container;

  ProviderContainer build(FakeGroupGiftRepository r) => ProviderContainer(
    overrides: [groupGiftRepositoryProvider.overrideWithValue(r)],
  );

  setUp(() {
    repo = FakeGroupGiftRepository();
    container = build(repo);
  });

  tearDown(() => container.dispose());

  group('CreateGroupGiftController', () {
    /// A date the picker would allow: the server refuses one already past.
    final aDate = DateTime.now().add(const Duration(days: 7));

    test(
      'needs a title, a UPI ID, a goal and a deadline before it can submit',
      () {
        final notifier = container.read(
          createGroupGiftProvider('item_1').notifier,
        );
        expect(
          container.read(createGroupGiftProvider('item_1')).canSubmit,
          isFalse,
        );

        notifier.primeGoal(kItemMinor);
        expect(
          container.read(createGroupGiftProvider('item_1')).canSubmit,
          isFalse,
        );

        notifier.setTitle("Siya's birthday gift");
        // Still not submittable: nobody can be asked to pay into a blank UPI ID.
        expect(
          container.read(createGroupGiftProvider('item_1')).canSubmit,
          isFalse,
        );

        notifier.setUpiId('rohanr1@okaxis');
        // And still not: the chip-in card and the invitation both count down to
        // a deadline, and neither has anything to say without one.
        expect(
          container.read(createGroupGiftProvider('item_1')).canSubmit,
          isFalse,
        );

        notifier.setDeadline(aDate);
        expect(
          container.read(createGroupGiftProvider('item_1')).canSubmit,
          isTrue,
        );
      },
    );

    // The picker hands back midnight, and the server refuses a deadline that
    // has already passed — so a date chosen today would come back rejected for
    // being nine hours ago.
    test('a deadline is stored as the end of the day chosen', () {
      final notifier = container.read(
        createGroupGiftProvider('item_1').notifier,
      );

      notifier.setDeadline(DateTime(2026, 9, 20));

      expect(
        container.read(createGroupGiftProvider('item_1')).deadline,
        DateTime(2026, 9, 20, 23, 59, 59),
      );
    });

    test('whitespace is not a title', () {
      final notifier = container.read(
        createGroupGiftProvider('item_1').notifier,
      );
      notifier.primeGoal(kItemMinor);
      notifier.setUpiId('a@b');
      notifier.setTitle('   ');

      expect(
        container.read(createGroupGiftProvider('item_1')).canSubmit,
        isFalse,
      );
    });

    test('primeGoal does not overwrite a goal the host has edited', () {
      final notifier = container.read(
        createGroupGiftProvider('item_1').notifier,
      );
      notifier.primeGoal(kItemMinor);
      notifier.setGoal(1000000);
      notifier.primeGoal(kItemMinor);

      expect(
        container.read(createGroupGiftProvider('item_1')).goalAmountMinor,
        1000000,
      );
    });

    test('the custom chip is sorted in among the three, not appended', () {
      final notifier = container.read(
        createGroupGiftProvider('item_1').notifier,
      );
      notifier.setCustomAmount(150000);

      expect(
        container
            .read(createGroupGiftProvider('item_1'))
            .allSuggestedAmountsMinor,
        [50000, 100000, 150000, 200000],
      );
    });

    test('a custom amount equal to a preset does not double up', () {
      final notifier = container.read(
        createGroupGiftProvider('item_1').notifier,
      );
      notifier.setCustomAmount(100000);

      expect(
        container
            .read(createGroupGiftProvider('item_1'))
            .allSuggestedAmountsMinor,
        [50000, 100000, 200000],
      );
    });

    test(
      'submit sends the trimmed form and reuses one idempotency key',
      () async {
        final notifier = container.read(
          createGroupGiftProvider('item_1').notifier,
        );
        notifier.primeGoal(kItemMinor);
        notifier.setTitle("  Siya's birthday gift  ");
        notifier.setUpiId(' rohanr1@okaxis ');
        notifier.setMode(ContributionMode.custom);
        notifier.setDeadline(DateTime(2026, 9, 20));

        await notifier.submit();
        await notifier.submit();

        expect(repo.createArgs, hasLength(2));
        expect(repo.createArgs.first['title'], "Siya's birthday gift");
        expect(repo.createArgs.first['hostUpiId'], 'rohanr1@okaxis');
        expect(
          repo.createArgs.first['contributionMode'],
          ContributionMode.custom,
        );
        expect(
          repo.createArgs.first['deadline'],
          DateTime(2026, 9, 20, 23, 59, 59),
        );
        // A retry of the same intent must not claim the item twice.
        expect(
          repo.createArgs.first['idempotencyKey'],
          repo.createArgs.last['idempotencyKey'],
        );
      },
    );

    test('a claimed item is reported in the user’s terms', () async {
      repo.failWith = const ApiException(
        code: 'ITEM_ALREADY_CLAIMED',
        message: 'raw server text',
      );
      final notifier = container.read(
        createGroupGiftProvider('item_1').notifier,
      );
      notifier.primeGoal(kItemMinor);
      notifier.setTitle('t');
      notifier.setUpiId('a@b');
      notifier.setDeadline(aDate);

      expect(await notifier.submit(), isNull);
      expect(
        container.read(createGroupGiftProvider('item_1')).error,
        'Someone else has already claimed this item.',
      );
    });
  });

  group('GroupGiftController', () {
    test('seed skips the fetch the create flow just made', () async {
      final notifier = container.read(groupGiftProvider('gg_1').notifier);
      notifier.seed(buildGroupGift());
      await notifier.ensureLoaded();

      expect(repo.calls, isNot(contains('get')));
    });

    test('a locked bill says what still works instead of "not open"', () async {
      repo.failWith = const ApiException(
        code: 'GROUP_GIFT_BILL_LOCKED',
        message: 'raw server text',
      );

      final ok = await container
          .read(groupGiftProvider('gg_1').notifier)
          .addCharge(label: 'Delivery', amountMinor: 19900);

      expect(ok, isFalse);
      expect(
        container.read(groupGiftProvider('gg_1')).error,
        contains('contribution request'),
      );
    });

    test('removing a line passes the line id, not the item id', () async {
      await container
          .read(groupGiftProvider('gg_1').notifier)
          .removeGiftLine('line_9');

      expect(repo.calls, contains('removeGiftLine:line_9'));
    });

    test('contribute forwards the amount and key it was given', () async {
      await container
          .read(groupGiftProvider('gg_1').notifier)
          .contribute(amountMinor: 200000, idempotencyKey: 'key-1');

      expect(repo.calls, contains('contribute:200000:key-1'));
    });
  });

  group('SettlementController', () {
    test('loads the balance and the ledger together', () async {
      final r = FakeGroupGiftRepository(
        settlements: [buildSettlement()],
        stubBalance: const GroupGiftBalance(
          totalCostMinor: kGrandTotalMinor,
          pledgedMinor: 1934700,
          collectedMinor: 1934700,
          differenceMinor: 200000,
          direction: SettlementDirection.returnToContributors,
          contributorCount: 6,
        ),
      );
      final c = build(r);
      addTearDown(c.dispose);

      await c.read(settlementProvider('gg_1').notifier).ensureLoaded();
      final state = c.read(settlementProvider('gg_1'));

      expect(state.hasLedger, isTrue);
      expect(
        state.balance?.direction,
        SettlementDirection.returnToContributors,
      );
      expect(r.calls, containsAll(['balance', 'listSettlements']));
    });

    test('marking one row sent replaces only that row', () async {
      final r = FakeGroupGiftRepository(
        settlements: [
          buildSettlement(id: 'st_1'),
          buildSettlement(id: 'st_2'),
        ],
      );
      final c = build(r);
      addTearDown(c.dispose);

      await c.read(settlementProvider('gg_1').notifier).ensureLoaded();
      await c.read(settlementProvider('gg_1').notifier).markSent('st_1');

      final rows = c.read(settlementProvider('gg_1')).settlements;
      expect(rows, hasLength(2));
      expect(rows.first.status, SettlementStatus.sent);
      expect(rows.last.status, SettlementStatus.pending);
      // No refetch: marking a payment sent moves no money.
      expect(r.calls.where((call) => call == 'balance'), hasLength(1));
    });

    test('open excludes rows that are already settled', () async {
      final r = FakeGroupGiftRepository(
        settlements: [
          buildSettlement(id: 'st_1'),
          buildSettlement(id: 'st_2', status: SettlementStatus.confirmed),
          buildSettlement(id: 'st_3', status: SettlementStatus.cancelled),
        ],
      );
      final c = build(r);
      addTearDown(c.dispose);

      await c.read(settlementProvider('gg_1').notifier).ensureLoaded();

      expect(c.read(settlementProvider('gg_1')).open, hasLength(1));
    });

    test(
      'a top-up sends the explicit amount, not the derived shortfall',
      () async {
        await container
            .read(settlementProvider('gg_1').notifier)
            .requestTopUp(additionalAmountMinor: 200000);

        expect(container.read(settlementProvider('gg_1')).busy, isFalse);
        expect(repo.calls, contains('requestTopUp:200000'));
      },
    );

    test(
      'sharing a UPI ID passes the save-to-profile choice through',
      () async {
        await container
            .read(settlementProvider('gg_1').notifier)
            .shareUpi('st_1', upiId: 'me@okhdfc', saveToProfile: true);

        expect(repo.calls, contains('shareUpi:me@okhdfc:true'));
      },
    );
  });
}
