import 'package:flutter_test/flutter_test.dart';
import 'package:chip_tracker/services/side_pot/side_pot_calculator.dart';

void main() {
  group('SidePotCalculator', () {
    test('equal all-ins make one shared pot', () {
      final pots = SidePotCalculator.compute({'A': 500, 'B': 500, 'C': 500});
      expect(pots, hasLength(1));
      expect(pots.single.amount, 1500);
      expect(pots.single.eligible.toSet(), {'A', 'B', 'C'});
    });

    test('short all-in creates a main pot + side pot', () {
      // C is all-in for 50; A and B have 100 each.
      final pots = SidePotCalculator.compute({'A': 100, 'B': 100, 'C': 50});
      expect(pots, hasLength(2));
      // Main pot: 50 x 3 = 150, everyone eligible.
      expect(pots[0].amount, 150);
      expect(pots[0].eligible.toSet(), {'A', 'B', 'C'});
      // Side pot: 50 x 2 = 100, only A and B.
      expect(pots[1].amount, 100);
      expect(pots[1].eligible.toSet(), {'A', 'B'});
    });

    test('uncalled top bet is returned', () {
      // A shoved 100, B could only call 50.
      final pots = SidePotCalculator.compute({'A': 100, 'B': 50});
      expect(pots, hasLength(2));
      expect(pots[0].amount, 100); // A,B contest 50 each
      expect(pots[0].eligible.toSet(), {'A', 'B'});
      expect(pots[1].uncalledReturn, isTrue);
      expect(pots[1].amount, 50);
      expect(pots[1].eligible, ['A']);
    });

    test('base pot is added to the main pot', () {
      final pots =
          SidePotCalculator.compute({'A': 100, 'B': 100}, basePot: 40);
      expect(pots, hasLength(1));
      expect(pots.single.amount, 240); // 200 + 40 base
    });

    test('three different all-in amounts make three layers', () {
      final pots =
          SidePotCalculator.compute({'A': 300, 'B': 200, 'C': 100});
      expect(pots, hasLength(3));
      expect(pots[0].amount, 300); // 100 x 3, all eligible
      expect(pots[0].eligible.toSet(), {'A', 'B', 'C'});
      expect(pots[1].amount, 200); // 100 x 2 (A,B)
      expect(pots[1].eligible.toSet(), {'A', 'B'});
      expect(pots[2].uncalledReturn, isTrue); // A's top 100 uncalled
      expect(pots[2].amount, 100);
      expect(pots[2].eligible, ['A']);
    });
  });
}
