import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/game_providers.dart';
import '../../services/side_pot/side_pot_calculator.dart';

/// Standalone all-in side-pot calculator. Reads the active game's player names
/// only to pre-fill rows for convenience — it never writes to the game and
/// leaves no trace when closed.
class SidePotCalculatorScreen extends ConsumerStatefulWidget {
  const SidePotCalculatorScreen({super.key});

  @override
  ConsumerState<SidePotCalculatorScreen> createState() =>
      _SidePotCalculatorScreenState();
}

class _Row {
  final TextEditingController name;
  final TextEditingController amount;
  _Row(String initialName)
      : name = TextEditingController(text: initialName),
        amount = TextEditingController();
  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _SidePotCalculatorScreenState
    extends ConsumerState<SidePotCalculatorScreen> {
  final _baseController = TextEditingController();
  final List<_Row> _rows = [];
  List<SidePot>? _result;

  @override
  void initState() {
    super.initState();
    final session = ref.read(activeGameProvider);
    final names = session?.players.map((p) => p.name).toList() ?? const [];
    if (names.isEmpty) {
      _rows.addAll([_Row(''), _Row('')]);
    } else {
      _rows.addAll(names.map(_Row.new));
    }
  }

  @override
  void dispose() {
    _baseController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() => setState(() => _rows.add(_Row('')));

  void _removeRow(int index) => setState(() {
        _rows.removeAt(index).dispose();
        _result = null;
      });

  void _calculate() {
    final contributions = <String, double>{};
    for (final row in _rows) {
      final name = row.name.text.trim();
      final amount = double.tryParse(row.amount.text.trim()) ?? 0;
      if (name.isEmpty || amount <= 0) continue;
      // Combine duplicates just in case.
      contributions[name] = (contributions[name] ?? 0) + amount;
    }
    final base = double.tryParse(_baseController.text.trim()) ?? 0;
    setState(() {
      _result = contributions.length < 2
          ? <SidePot>[]
          : SidePotCalculator.compute(contributions, basePot: base);
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Side-Pot Calculator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Who was in at the all-in',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Enter each player and the total chips they put in this round.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _rows[i].name,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _rows[i].amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Chips in',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _rows.length > 2 ? () => _removeRow(i) : null,
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add),
              label: const Text('Add player'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _baseController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Chips already in the pot (optional)',
              helperText: 'Shared by everyone — added to the main pot',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.calculate),
            label: const Text('Split the pots'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 20),
          if (result != null) _buildResult(context, result),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, List<SidePot> pots) {
    if (pots.isEmpty) {
      return const Text('Add at least 2 players with chips to split the pots.');
    }
    // Label contested pots: first = "Main pot", then "Side pot 1", 2, ...
    var contestedSeen = 0;
    String labelFor(SidePot pot) {
      if (pot.uncalledReturn) return 'Returned to ${pot.eligible.first}';
      final label = contestedSeen == 0 ? 'Main pot' : 'Side pot $contestedSeen';
      contestedSeen++;
      return label;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Result', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final pot in pots)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    pot.uncalledReturn ? Icons.reply : Icons.savings,
                    color: pot.uncalledReturn ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          labelFor(pot),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        // No maxLines — grows to show every eligible name.
                        Text(
                          pot.uncalledReturn
                              ? 'Uncalled bet'
                              : 'Contested by: ${pot.eligible.join(', ')}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pot.amount == pot.amount.roundToDouble()
                        ? pot.amount.toStringAsFixed(0)
                        : pot.amount.toStringAsFixed(2),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
