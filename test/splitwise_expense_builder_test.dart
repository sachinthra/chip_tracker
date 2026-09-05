import 'package:flutter_test/flutter_test.dart';
import 'package:chip_tracker/models/game_session.dart';
import 'package:chip_tracker/models/ledger_entry.dart';
import 'package:chip_tracker/models/player.dart';
import 'package:chip_tracker/services/splitwise/splitwise_expense_builder.dart';

void main() {
  Player linked(String name, String swId) => Player(
        name: name,
        source: PlayerSource.splitwise,
        splitwiseUserId: swId,
      );

  group('SplitwiseExpenseBuilder', () {
    test('winners paid, losers owe; totals reconcile to cost', () {
      final alice = linked('Alice', '11');
      final bob = linked('Bob', '22');
      // 500 chips ÷ 4 = ₹125. Alice wins Bob's stack.
      final session = GameSession(
        players: [alice, bob],
        ledger: [
          LedgerEntry.buyIn(playerId: alice.id, chips: 500),
          LedgerEntry.buyIn(playerId: bob.id, chips: 500),
          LedgerEntry.cashOut(playerId: alice.id, chips: 1000),
          LedgerEntry.cashOut(playerId: bob.id, chips: 0),
        ],
      );

      final result = SplitwiseExpenseBuilder.build(session);

      expect(result.isPushable, isTrue);
      final draft = result.draft!;
      expect(draft.cost, closeTo(125.0, 0.001));

      final paidTotal = draft.shares.fold<double>(0, (s, x) => s + x.paidShare);
      final owedTotal = draft.shares.fold<double>(0, (s, x) => s + x.owedShare);
      expect(paidTotal, closeTo(draft.cost, 0.001));
      expect(owedTotal, closeTo(draft.cost, 0.001));

      final aliceShare = draft.shares.firstWhere((s) => s.userId == '11');
      final bobShare = draft.shares.firstWhere((s) => s.userId == '22');
      expect(aliceShare.paidShare, closeTo(125.0, 0.001));
      expect(aliceShare.owedShare, 0);
      expect(bobShare.owedShare, closeTo(125.0, 0.001));
      expect(bobShare.paidShare, 0);
    });

    test('flags players with a non-zero result but no Splitwise link', () {
      final alice = linked('Alice', '11');
      final ghost = Player(name: 'Carl'); // no splitwiseUserId
      final session = GameSession(
        players: [alice, ghost],
        ledger: [
          LedgerEntry.buyIn(playerId: alice.id, chips: 500),
          LedgerEntry.buyIn(playerId: ghost.id, chips: 500),
          LedgerEntry.cashOut(playerId: alice.id, chips: 1000),
          LedgerEntry.cashOut(playerId: ghost.id, chips: 0),
        ],
      );

      final result = SplitwiseExpenseBuilder.build(session);

      expect(result.isPushable, isFalse);
      expect(result.unlinkedPlayers, contains('Carl'));
    });

    test('everyone even yields nothing to push', () {
      final alice = linked('Alice', '11');
      final bob = linked('Bob', '22');
      final session = GameSession(
        players: [alice, bob],
        ledger: [
          LedgerEntry.buyIn(playerId: alice.id, chips: 500),
          LedgerEntry.buyIn(playerId: bob.id, chips: 500),
          LedgerEntry.cashOut(playerId: alice.id, chips: 500),
          LedgerEntry.cashOut(playerId: bob.id, chips: 500),
        ],
      );

      final result = SplitwiseExpenseBuilder.build(session);

      expect(result.everyoneEven, isTrue);
      expect(result.isPushable, isFalse);
    });

    test('a ghost player with zero net does not block the push', () {
      final alice = linked('Alice', '11');
      final bob = linked('Bob', '22');
      final ghost = Player(name: 'Dan'); // sat out even
      final session = GameSession(
        players: [alice, bob, ghost],
        ledger: [
          LedgerEntry.buyIn(playerId: alice.id, chips: 500),
          LedgerEntry.buyIn(playerId: bob.id, chips: 500),
          LedgerEntry.buyIn(playerId: ghost.id, chips: 500),
          LedgerEntry.cashOut(playerId: alice.id, chips: 1000),
          LedgerEntry.cashOut(playerId: bob.id, chips: 0),
          LedgerEntry.cashOut(playerId: ghost.id, chips: 500),
        ],
      );

      final result = SplitwiseExpenseBuilder.build(session);

      expect(result.isPushable, isTrue);
      // Only Alice and Bob appear; the even ghost is omitted.
      expect(result.draft!.shares.length, 2);
    });

    test('non-exact divisor still reconciles paid == owed == cost', () {
      final a = linked('A', '1');
      final b = linked('B', '2');
      final c = linked('C', '3');
      // ÷3 makes ₹ values non-terminating; reconciliation must still balance.
      final session = GameSession(
        chipToCurrencyDivisor: 3,
        players: [a, b, c],
        ledger: [
          LedgerEntry.buyIn(playerId: a.id, chips: 500),
          LedgerEntry.buyIn(playerId: b.id, chips: 500),
          LedgerEntry.buyIn(playerId: c.id, chips: 500),
          LedgerEntry.cashOut(playerId: a.id, chips: 1000),
          LedgerEntry.cashOut(playerId: b.id, chips: 500),
          LedgerEntry.cashOut(playerId: c.id, chips: 0),
        ],
      );

      final draft = SplitwiseExpenseBuilder.build(session).draft!;
      final paidTotal = draft.shares.fold<double>(0, (s, x) => s + x.paidShare);
      final owedTotal = draft.shares.fold<double>(0, (s, x) => s + x.owedShare);
      expect(paidTotal, closeTo(draft.cost, 0.001));
      expect(owedTotal, closeTo(draft.cost, 0.001));
    });
  });
}
