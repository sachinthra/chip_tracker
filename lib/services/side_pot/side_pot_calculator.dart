/// One pot in an all-in showdown: its amount and who can win it. When
/// [uncalledReturn] is true, the amount is an uncalled bet returned to the
/// single [eligible] player rather than a contested pot.
class SidePot {
  final double amount;
  final List<String> eligible;
  final bool uncalledReturn;

  const SidePot({
    required this.amount,
    required this.eligible,
    this.uncalledReturn = false,
  });
}

/// Splits an all-in situation into a main pot + side pots.
///
/// Given each still-in player's total contribution for the round, it layers the
/// pot by contribution level: everyone shares the lowest layer (main pot), and
/// each higher layer is contestable only by the players who put in that much.
/// A top contribution nobody matched is returned as an uncalled bet.
class SidePotCalculator {
  /// [contributions]: player name -> amount put in this all-in round.
  /// [basePot]: chips already in the middle (antes/earlier betting) shared by
  /// everyone — added onto the main pot.
  static List<SidePot> compute(
    Map<String, double> contributions, {
    double basePot = 0,
  }) {
    final entries =
        contributions.entries.where((e) => e.value > 0).toList();
    final levels = entries.map((e) => e.value).toSet().toList()..sort();

    final pots = <SidePot>[];
    var prev = 0.0;
    var mainPotFilled = false;

    for (final level in levels) {
      final layer = level - prev;
      prev = level;
      final contributors = entries
          .where((e) => e.value >= level - 1e-9)
          .map((e) => e.key)
          .toList();
      final potAmount = layer * contributors.length;
      if (potAmount <= 1e-9) continue;

      if (contributors.length == 1) {
        pots.add(SidePot(
          amount: _round2(potAmount),
          eligible: [contributors.first],
          uncalledReturn: true,
        ));
      } else {
        var amount = potAmount;
        if (!mainPotFilled) {
          amount += basePot;
          mainPotFilled = true;
        }
        pots.add(SidePot(amount: _round2(amount), eligible: contributors));
      }
    }

    // No contested pot but there was base money — everyone shares it.
    if (!mainPotFilled && basePot > 0) {
      pots.insert(
        0,
        SidePot(amount: _round2(basePot), eligible: contributions.keys.toList()),
      );
    }
    return pots;
  }

  static double _round2(double v) => (v * 100).round() / 100;
}
