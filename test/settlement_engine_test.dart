import 'package:flutter_test/flutter_test.dart';
import 'package:chip_tracker/models/game_session.dart';
import 'package:chip_tracker/models/ledger_entry.dart';
import 'package:chip_tracker/models/player.dart';
import 'package:chip_tracker/services/settlement/settlement_engine.dart';

void main() {
  group('SettlementEngine', () {
    test('two-player game: loser pays winner directly', () {
      final alice = Player(name: 'Alice');
      final bob = Player(name: 'Bob');
      final session = GameSession(
        players: [alice, bob],
        ledger: [
          LedgerEntry.buyIn(playerId: alice.id, chips: 500),
          LedgerEntry.buyIn(playerId: bob.id, chips: 500),
          LedgerEntry.cashOut(playerId: alice.id, chips: 1000),
          LedgerEntry.cashOut(playerId: bob.id, chips: 0),
        ],
      );

      final transactions = SettlementEngine.settle(session);

      expect(transactions, hasLength(1));
      expect(transactions.single.fromPlayerId, bob.id);
      expect(transactions.single.toPlayerId, alice.id);
      expect(transactions.single.amount, closeTo(125.0, 0.001));
    });

    test('a loan must be repaid even if both players break even at the table', () {
      // Alice lends Bob 500 chips mid-game, but both cash out for exactly
      // what they bought in for (i.e. the loan was never reversed with a
      // matching entry) — Bob still owes Alice the loan directly.
      final alice = Player(name: 'Alice');
      final bob = Player(name: 'Bob');
      final session = GameSession(
        players: [alice, bob],
        ledger: [
          LedgerEntry.buyIn(playerId: alice.id, chips: 500),
          LedgerEntry.buyIn(playerId: bob.id, chips: 500),
          LedgerEntry.loan(lenderId: alice.id, borrowerId: bob.id, chips: 500),
          LedgerEntry.cashOut(playerId: alice.id, chips: 500),
          LedgerEntry.cashOut(playerId: bob.id, chips: 500),
        ],
      );

      final transactions = SettlementEngine.settle(session);

      expect(transactions, hasLength(1));
      expect(transactions.single.fromPlayerId, bob.id);
      expect(transactions.single.toPlayerId, alice.id);
      expect(transactions.single.amount, closeTo(125.0, 0.001));
    });

    test('a loan is still owed even if the borrower loses it at the table', () {
      // Alice lends Bob 500 chips; Bob then loses everything to Carl. Bob
      // still owes Alice the loan on top of his own table loss.
      final alice = Player(name: 'Alice');
      final bob = Player(name: 'Bob');
      final carl = Player(name: 'Carl');
      final session = GameSession(
        players: [alice, bob, carl],
        ledger: [
          LedgerEntry.buyIn(playerId: alice.id, chips: 500),
          LedgerEntry.buyIn(playerId: bob.id, chips: 500),
          LedgerEntry.buyIn(playerId: carl.id, chips: 500),
          LedgerEntry.loan(lenderId: alice.id, borrowerId: bob.id, chips: 500),
          LedgerEntry.cashOut(playerId: alice.id, chips: 0),
          LedgerEntry.cashOut(playerId: bob.id, chips: 0),
          LedgerEntry.cashOut(playerId: carl.id, chips: 1500),
        ],
      );

      final balances = SettlementEngine.computeNetBalances(session);

      expect(balances[alice.id], closeTo(0.0, 0.001));
      expect(balances[bob.id], closeTo(-250.0, 0.001));
      expect(balances[carl.id], closeTo(250.0, 0.001));
    });

    test('three-player game minimizes transaction count', () {
      final alice = Player(name: 'Alice');
      final bob = Player(name: 'Bob');
      final carl = Player(name: 'Carl');
      final session = GameSession(
        players: [alice, bob, carl],
        ledger: [
          LedgerEntry.buyIn(playerId: alice.id, chips: 500),
          LedgerEntry.buyIn(playerId: bob.id, chips: 500),
          LedgerEntry.buyIn(playerId: carl.id, chips: 500),
          LedgerEntry.cashOut(playerId: alice.id, chips: 1500),
          LedgerEntry.cashOut(playerId: bob.id, chips: 0),
          LedgerEntry.cashOut(playerId: carl.id, chips: 0),
        ],
      );

      final transactions = SettlementEngine.settle(session);

      // Alice is owed 250 total; minimal settlement is exactly 2 transactions.
      expect(transactions, hasLength(2));
      final totalToAlice = transactions
          .where((t) => t.toPlayerId == alice.id)
          .fold(0.0, (sum, t) => sum + t.amount);
      expect(totalToAlice, closeTo(250.0, 0.001));
    });

    test('net balances always sum to zero', () {
      final alice = Player(name: 'Alice');
      final bob = Player(name: 'Bob');
      final carl = Player(name: 'Carl');
      final session = GameSession(
        players: [alice, bob, carl],
        ledger: [
          LedgerEntry.buyIn(playerId: alice.id, chips: 500),
          LedgerEntry.buyIn(playerId: bob.id, chips: 1000),
          LedgerEntry.buyIn(playerId: carl.id, chips: 500),
          LedgerEntry.cashOut(playerId: alice.id, chips: 300),
          LedgerEntry.cashOut(playerId: bob.id, chips: 1200),
          LedgerEntry.cashOut(playerId: carl.id, chips: 500),
        ],
      );

      final balances = SettlementEngine.computeNetBalances(session);
      final sum = balances.values.fold(0.0, (a, b) => a + b);

      expect(sum, closeTo(0.0, 0.001));
    });
  });
}
