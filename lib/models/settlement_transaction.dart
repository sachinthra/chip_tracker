/// A single money transfer required to settle the table with the minimum
/// possible number of transactions ("debt simplification").
class SettlementTransaction {
  final String fromPlayerId;
  final String toPlayerId;
  final double amount;

  const SettlementTransaction({
    required this.fromPlayerId,
    required this.toPlayerId,
    required this.amount,
  });

  @override
  String toString() =>
      'SettlementTransaction($fromPlayerId -> $toPlayerId: $amount)';
}
