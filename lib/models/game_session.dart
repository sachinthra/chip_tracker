import 'ledger_entry.dart';
import 'player.dart';

enum GameSessionStatus { active, cashedOut, settled }

/// A single night of poker: its players, its full ledger of buy-ins/loans/
/// cash-outs, and the currency rules used to convert chips to real money.
class GameSession {
  final String id;
  final DateTime createdAt;

  /// Chips awarded per "stack" when the Bank drags onto a player. Default 500.
  final int chipsPerBuyIn;

  /// How many chips equal one currency unit (e.g. 4 -> 500 chips = ₹125).
  final double chipToCurrencyDivisor;

  /// ISO currency code shown in the UI and pushed to Splitwise (e.g. 'INR').
  final String currencyCode;

  final List<Player> players;
  final List<LedgerEntry> ledger;
  final GameSessionStatus status;

  /// Splitwise group this session settles into, once linked.
  final String? splitwiseGroupId;

  GameSession({
    String? id,
    DateTime? createdAt,
    this.chipsPerBuyIn = 500,
    this.chipToCurrencyDivisor = 4,
    this.currencyCode = 'INR',
    List<Player>? players,
    List<LedgerEntry>? ledger,
    this.status = GameSessionStatus.active,
    this.splitwiseGroupId,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now(),
        players = players ?? [],
        ledger = ledger ?? [];

  double get currencyPerChip => 1 / chipToCurrencyDivisor;

  double chipsToCurrency(int chips) => chips * currencyPerChip;

  /// Whether a player named [name] already exists (case-insensitive, trimmed).
  bool hasPlayerNamed(String name) {
    final needle = name.trim().toLowerCase();
    return players.any((p) => p.name.trim().toLowerCase() == needle);
  }

  /// Total chips [playerId] has bought in for (money they've put in so far).
  int totalBuyInChips(String playerId) => ledger
      .where((e) => e.type == LedgerEntryType.buyIn && e.toPlayerId == playerId)
      .fold(0, (sum, e) => sum + e.chipAmount);

  /// Total chips [playerId] cashed out with at the end of the night.
  /// Zero until a [LedgerEntryType.cashOut] entry has been recorded for them.
  int totalCashOutChips(String playerId) => ledger
      .where((e) => e.type == LedgerEntryType.cashOut && e.toPlayerId == playerId)
      .fold(0, (sum, e) => sum + e.chipAmount);

  /// Whether [playerId] has a recorded cash-out (i.e. has left the table /
  /// finalized their remaining chips). Distinct from cashing out with 0 chips.
  bool hasCashedOut(String playerId) => ledger
      .any((e) => e.type == LedgerEntryType.cashOut && e.toPlayerId == playerId);

  /// Total chips [playerId] has lent out to other players (as lender).
  int totalLoanGivenChips(String playerId) => ledger
      .where((e) => e.type == LedgerEntryType.loan && e.fromPlayerId == playerId)
      .fold(0, (sum, e) => sum + e.chipAmount);

  /// Total chips [playerId] has borrowed from other players (as borrower).
  int totalLoanReceivedChips(String playerId) => ledger
      .where((e) => e.type == LedgerEntryType.loan && e.toPlayerId == playerId)
      .fold(0, (sum, e) => sum + e.chipAmount);

  /// Live estimate of chips physically in front of [playerId] right now,
  /// derived from buy-ins and loans. This is only a display convenience —
  /// the authoritative number is whatever is entered on the Cash-Out screen,
  /// since it accounts for actual chips on the table (side pots, misdeals, etc).
  int currentChipStack(String playerId) {
    var balance = 0;
    for (final entry in ledger) {
      switch (entry.type) {
        case LedgerEntryType.buyIn:
          if (entry.toPlayerId == playerId) balance += entry.chipAmount;
        case LedgerEntryType.loan:
          if (entry.toPlayerId == playerId) balance += entry.chipAmount;
          if (entry.fromPlayerId == playerId) balance -= entry.chipAmount;
        case LedgerEntryType.cashOut:
          if (entry.toPlayerId == playerId) balance -= entry.chipAmount;
      }
    }
    return balance;
  }

  /// Net currency result for [playerId], made of two independent channels
  /// that are simply added together (never netted against each other):
  ///
  /// 1. Table result: `cashOut - buyIn` — standard poker profit/loss.
  /// 2. Loan ledger: `loanGiven - loanReceived` — a personal IOU that must
  ///    be repaid regardless of how the table itself played out (the
  ///    borrower bears the risk of what happens to the borrowed chips).
  ///
  /// A loan only stops counting as owed once it's explicitly reversed with
  /// a matching [LedgerEntryType.loan] entry in the other direction — it is
  /// NOT inferred from final chip counts, since we can't tell whether a
  /// borrower's final stack still contains the lender's chips or not.
  ///
  /// Both channels independently sum to zero across all players (chips are
  /// conserved at the table, and every loan has one giver and one equal
  /// receiver), so their sum does too — which is what SettlementEngine
  /// requires to simplify debts correctly.
  double netResultFor(String playerId) {
    final tableResult = totalCashOutChips(playerId) - totalBuyInChips(playerId);
    final loanResult = totalLoanGivenChips(playerId) - totalLoanReceivedChips(playerId);
    return chipsToCurrency(tableResult + loanResult);
  }

  GameSession copyWith({
    int? chipsPerBuyIn,
    double? chipToCurrencyDivisor,
    String? currencyCode,
    List<Player>? players,
    List<LedgerEntry>? ledger,
    GameSessionStatus? status,
    String? splitwiseGroupId,
  }) {
    return GameSession(
      id: id,
      createdAt: createdAt,
      chipsPerBuyIn: chipsPerBuyIn ?? this.chipsPerBuyIn,
      chipToCurrencyDivisor: chipToCurrencyDivisor ?? this.chipToCurrencyDivisor,
      currencyCode: currencyCode ?? this.currencyCode,
      players: players ?? this.players,
      ledger: ledger ?? this.ledger,
      status: status ?? this.status,
      splitwiseGroupId: splitwiseGroupId ?? this.splitwiseGroupId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'chipsPerBuyIn': chipsPerBuyIn,
        'chipToCurrencyDivisor': chipToCurrencyDivisor,
        'currencyCode': currencyCode,
        'players': players.map((p) => p.toJson()).toList(),
        'ledger': ledger.map((e) => e.toJson()).toList(),
        'status': status.name,
        'splitwiseGroupId': splitwiseGroupId,
      };

  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        chipsPerBuyIn: json['chipsPerBuyIn'] as int? ?? 500,
        chipToCurrencyDivisor:
            (json['chipToCurrencyDivisor'] as num?)?.toDouble() ?? 4,
        currencyCode: json['currencyCode'] as String? ?? 'INR',
        // Hive returns nested maps as Map<dynamic, dynamic> after a real
        // disk read (not the exact Map<String, dynamic> we wrote), so each
        // entry must be re-wrapped rather than cast directly.
        players: (json['players'] as List<dynamic>)
            .map((p) => Player.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList(),
        ledger: (json['ledger'] as List<dynamic>)
            .map((e) => LedgerEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        status: GameSessionStatus.values.byName(
          json['status'] as String? ?? 'active',
        ),
        splitwiseGroupId: json['splitwiseGroupId'] as String?,
      );
}
