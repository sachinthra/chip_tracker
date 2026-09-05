import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A self-contained side game for the "poker + dice" variation: roll 2 dice
/// three times; each round's target is the sum (2–12). Kept fully independent
/// of the money tracking — it never touches buy-ins or settlement.
class DiceRollerScreen extends StatefulWidget {
  const DiceRollerScreen({super.key});

  @override
  State<DiceRollerScreen> createState() => _DiceRollerScreenState();
}

class _DiceRollerScreenState extends State<DiceRollerScreen> {
  static const int _rounds = 3;
  final _random = Random();
  final List<List<int>> _rolls = [];

  bool get _done => _rolls.length >= _rounds;

  void _rollNext() {
    if (_done) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _rolls.add([_random.nextInt(6) + 1, _random.nextInt(6) + 1]);
    });
  }

  void _reset() => setState(() => _rolls.clear());

  /// Target for a round: the dice sum, reduced to a single digit by adding its
  /// digits when it's over 9 (e.g. 12 -> 1+2 = 3).
  static int target(int d1, int d2) {
    final sum = d1 + d2;
    return sum > 9 ? sum ~/ 10 + sum % 10 : sum;
  }

  @override
  Widget build(BuildContext context) {
    final targets = _rolls.map((r) => target(r[0], r[1])).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Dice Roll')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (var i = 0; i < _rounds; i++)
                  _RoundRow(
                    round: i + 1,
                    dice: i < _rolls.length ? _rolls[i] : null,
                  ),
                const SizedBox(height: 16),
                if (_done)
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Targets to beat',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            targets.join('   ·   '),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Cards: A = 1, 2–9 face value, 10/J/Q/K = 0. '
                  'Use your 3 cards to get closest to each target.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _rolls.isEmpty ? null : _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _done ? null : _rollNext,
                      icon: const Icon(Icons.casino),
                      label: Text(_done
                          ? 'Done'
                          : 'Roll ${_rolls.length + 1} of $_rounds'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({required this.round, required this.dice});

  final int round;
  final List<int>? dice;

  @override
  Widget build(BuildContext context) {
    final rolled = dice != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text('Round $round',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          _Die(value: rolled ? dice![0] : null),
          const SizedBox(width: 12),
          _Die(value: rolled ? dice![1] : null),
          const Spacer(),
          if (rolled) _targetBadge(context),
        ],
      ),
    );
  }

  Widget _targetBadge(BuildContext context) {
    final sum = dice![0] + dice![1];
    final reduced = _DiceRollerScreenState.target(dice![0], dice![1]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$reduced',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (sum > 9)
            Text('$sum → $reduced',
                style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// A dice face drawn with pips (null = not yet rolled).
class _Die extends StatelessWidget {
  const _Die({required this.value});

  final int? value;

  static const Map<int, List<Alignment>> _pips = {
    1: [Alignment.center],
    2: [Alignment.topLeft, Alignment.bottomRight],
    3: [Alignment.topLeft, Alignment.center, Alignment.bottomRight],
    4: [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight
    ],
    5: [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.center,
      Alignment.bottomLeft,
      Alignment.bottomRight
    ],
    6: [
      Alignment.topLeft,
      Alignment.centerLeft,
      Alignment.bottomLeft,
      Alignment.topRight,
      Alignment.centerRight,
      Alignment.bottomRight
    ],
  };

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onSurface.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(7),
      child: value == null
          ? Icon(Icons.help_outline, size: 20, color: onSurface.withValues(alpha: 0.3))
          : Stack(
              children: [
                for (final align in _pips[value!]!)
                  Align(
                    alignment: align,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: onSurface, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
    );
  }
}
