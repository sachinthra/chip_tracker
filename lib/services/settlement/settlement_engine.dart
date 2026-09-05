import '../../models/game_session.dart';
import '../../models/settlement_transaction.dart';

/// Computes the minimal set of payments needed to settle a table ("debt
/// simplification"), using the classic greedy max-creditor / max-debtor
/// matching algorithm.
///
/// Net balance per player combines two independent channels (see
/// [GameSession.netResultFor]):
///  1. Table result: `cashOut - buyIn`.
///  2. Loan ledger: `loanGiven - loanReceived`, a personal IOU that must be
///     repaid regardless of table outcome.
/// Both channels sum to zero across all players, so the combined balances
/// always sum to ~0, which is what the simplification below requires.
class SettlementEngine {
  static const double _epsilon = 0.01; // currency rounding tolerance

  /// Net balance per player id: positive = owed money, negative = owes money.
  static Map<String, double> computeNetBalances(GameSession session) {
    return {
      for (final player in session.players)
        player.id: _round2(session.netResultFor(player.id)),
    };
  }

  /// Greedily matches the largest creditor with the largest debtor, repeating
  /// until every balance is settled. This minimizes the number of
  /// transactions required for the group as a whole.
  static List<SettlementTransaction> simplify(Map<String, double> netBalances) {
    final balances = Map<String, double>.from(netBalances)
      ..removeWhere((_, v) => v.abs() < _epsilon);

    final transactions = <SettlementTransaction>[];

    while (balances.isNotEmpty) {
      final creditor = balances.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final debtor = balances.entries.reduce((a, b) => a.value <= b.value ? a : b);

      if (creditor.value < _epsilon || debtor.value > -_epsilon) break;

      final amount = _round2(
        creditor.value < -debtor.value ? creditor.value : -debtor.value,
      );
      if (amount <= 0) break;

      transactions.add(SettlementTransaction(
        fromPlayerId: debtor.key,
        toPlayerId: creditor.key,
        amount: amount,
      ));

      final remainingCredit = _round2(creditor.value - amount);
      final remainingDebt = _round2(debtor.value + amount);

      remainingCredit.abs() < _epsilon
          ? balances.remove(creditor.key)
          : balances[creditor.key] = remainingCredit;

      remainingDebt.abs() < _epsilon
          ? balances.remove(debtor.key)
          : balances[debtor.key] = remainingDebt;
    }

    return transactions;
  }

  /// Convenience: derives net balances from [session] and simplifies them.
  static List<SettlementTransaction> settle(GameSession session) =>
      simplify(computeNetBalances(session));

  static double _round2(double v) => (v * 100).round() / 100;
}
