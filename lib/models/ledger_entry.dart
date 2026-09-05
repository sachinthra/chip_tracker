import 'package:uuid/uuid.dart';

/// The three (and only three) things we ever record during play.
enum LedgerEntryType { buyIn, loan, cashOut }

/// A single immutable event in a game's history: a buy-in from the Bank, a
/// chip loan between two players, or an end-of-night cash-out.
///
/// [fromPlayerId] is null for a [LedgerEntryType.buyIn] (the Bank has no
/// player id). For [LedgerEntryType.loan] it is the lender, and for
/// [LedgerEntryType.cashOut] it is unused (also null).
class LedgerEntry {
  final String id;
  final LedgerEntryType type;
  final String? fromPlayerId;
  final String toPlayerId;
  final int chipAmount;
  final DateTime timestamp;

  LedgerEntry({
    String? id,
    required this.type,
    this.fromPlayerId,
    required this.toPlayerId,
    required this.chipAmount,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  /// A +500 buy-in from the Bank to [playerId].
  factory LedgerEntry.buyIn({required String playerId, required int chips}) =>
      LedgerEntry(type: LedgerEntryType.buyIn, toPlayerId: playerId, chipAmount: chips);

  /// A chip loan: [lenderId] hands [chips] chips to [borrowerId].
  factory LedgerEntry.loan({
    required String lenderId,
    required String borrowerId,
    required int chips,
  }) =>
      LedgerEntry(
        type: LedgerEntryType.loan,
        fromPlayerId: lenderId,
        toPlayerId: borrowerId,
        chipAmount: chips,
      );

  /// [playerId] cashes out with [chips] chips at the end of the night.
  factory LedgerEntry.cashOut({required String playerId, required int chips}) =>
      LedgerEntry(type: LedgerEntryType.cashOut, toPlayerId: playerId, chipAmount: chips);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'fromPlayerId': fromPlayerId,
        'toPlayerId': toPlayerId,
        'chipAmount': chipAmount,
        'timestamp': timestamp.toIso8601String(),
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: json['id'] as String,
        type: LedgerEntryType.values.byName(json['type'] as String),
        fromPlayerId: json['fromPlayerId'] as String?,
        toPlayerId: json['toPlayerId'] as String,
        chipAmount: json['chipAmount'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
