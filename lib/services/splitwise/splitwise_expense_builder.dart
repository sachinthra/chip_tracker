import '../../models/game_session.dart';

/// One user's role in a Splitwise expense: how much they paid vs owe.
class SplitwiseExpenseShare {
  final String userId;
  final double paidShare;
  final double owedShare;

  const SplitwiseExpenseShare({
    required this.userId,
    required this.paidShare,
    required this.owedShare,
  });
}

/// A ready-to-push Splitwise expense representing the whole night's result as
/// a single expense: winners "paid" their winnings, losers "owe" their losses.
class SplitwiseExpenseDraft {
  final double cost;
  final List<SplitwiseExpenseShare> shares;

  const SplitwiseExpenseDraft({required this.cost, required this.shares});
}

/// Outcome of trying to turn a settled game into a Splitwise expense.
class SplitwiseExpenseResult {
  /// The pushable expense, or null when it can't be pushed.
  final SplitwiseExpenseDraft? draft;

  /// Names of players with a non-zero result but no linked Splitwise account.
  final List<String> unlinkedPlayers;

  /// True when nobody won or lost anything (nothing to push).
  final bool everyoneEven;

  const SplitwiseExpenseResult({
    this.draft,
    this.unlinkedPlayers = const [],
    this.everyoneEven = false,
  });

  bool get isPushable => draft != null;
}

/// Builds a single combined Splitwise expense from a settled [GameSession].
///
/// Encoding: each player's net (cash-out+loans − buy-in) becomes their role in
/// one expense — winners' net is their `paid_share` (owed 0), losers' net is
/// their `owed_share` (paid 0). Splitwise then applies each player's exact net
/// balance change. Because nets sum to ~0, the paid total equals the owed
/// total (== the expense cost).
class SplitwiseExpenseBuilder {
  static const double _epsilon = 0.005; // half a cent

  static SplitwiseExpenseResult build(GameSession session) {
    final nets = <String, double>{
      for (final p in session.players) p.id: _round2(session.netResultFor(p.id)),
    };

    final nonZeroPlayers =
        session.players.where((p) => nets[p.id]!.abs() >= 0.01).toList();
    if (nonZeroPlayers.isEmpty) {
      return const SplitwiseExpenseResult(everyoneEven: true);
    }

    final unlinked = nonZeroPlayers
        .where((p) => p.splitwiseUserId == null)
        .map((p) => p.name)
        .toList();
    if (unlinked.isNotEmpty) {
      return SplitwiseExpenseResult(unlinkedPlayers: unlinked);
    }

    var cost = 0.0;
    final shares = <SplitwiseExpenseShare>[];
    for (final player in nonZeroPlayers) {
      final net = nets[player.id]!;
      if (net > 0) {
        cost += net;
        shares.add(SplitwiseExpenseShare(
          userId: player.splitwiseUserId!,
          paidShare: net,
          owedShare: 0,
        ));
      } else {
        shares.add(SplitwiseExpenseShare(
          userId: player.splitwiseUserId!,
          paidShare: 0,
          owedShare: -net,
        ));
      }
    }
    cost = _round2(cost);

    // Rounding each net to cents can leave owed total off cost by a cent or
    // two; absorb the residual on the largest owed share so Splitwise's
    // paid==owed==cost invariant holds exactly.
    final owedTotal =
        _round2(shares.fold<double>(0, (sum, s) => sum + s.owedShare));
    final residual = _round2(cost - owedTotal);
    if (residual.abs() >= _epsilon) {
      var largestIndex = -1;
      var largestOwed = -1.0;
      for (var i = 0; i < shares.length; i++) {
        if (shares[i].owedShare > largestOwed) {
          largestOwed = shares[i].owedShare;
          largestIndex = i;
        }
      }
      if (largestIndex >= 0) {
        final adjusted = shares[largestIndex];
        shares[largestIndex] = SplitwiseExpenseShare(
          userId: adjusted.userId,
          paidShare: adjusted.paidShare,
          owedShare: _round2(adjusted.owedShare + residual),
        );
      }
    }

    return SplitwiseExpenseResult(
      draft: SplitwiseExpenseDraft(cost: cost, shares: shares),
    );
  }

  static double _round2(double v) => (v * 100).round() / 100;
}
