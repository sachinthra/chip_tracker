import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../models/game_session.dart';
import '../../models/player.dart';
import '../../providers/game_providers.dart';
import '../game_table/game_table_screen.dart';

/// Configure chip/currency rules, seat "Ghost" players, and start a game.
class GameSetupScreen extends ConsumerStatefulWidget {
  const GameSetupScreen({super.key});

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen> {
  final _chipsController = TextEditingController(
    text: AppConstants.defaultChipsPerBuyIn.toString(),
  );
  final _divisorController = TextEditingController(
    text: AppConstants.defaultChipToCurrencyDivisor.toStringAsFixed(0),
  );
  final _currencyController = TextEditingController(
    text: AppConstants.defaultCurrencyCode,
  );
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<String> _playerNames = [];
  String? _error;

  @override
  void dispose() {
    _chipsController.dispose();
    _divisorController.dispose();
    _currencyController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _addPlayer() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _playerNames.add(name);
      _nameController.clear();
      _error = null;
    });
  }

  void _removePlayer(int index) {
    setState(() => _playerNames.removeAt(index));
  }

  void _startGame() {
    if (!_formKey.currentState!.validate()) return;
    if (_playerNames.length < 2) {
      setState(() => _error = 'Add at least 2 players to start a game.');
      return;
    }

    final chips = int.parse(_chipsController.text.trim());
    final divisor = double.parse(_divisorController.text.trim());
    final currency = _currencyController.text.trim().toUpperCase();
    final players = _playerNames.map((name) => Player(name: name)).toList();

    final session = GameSession(
      chipsPerBuyIn: chips,
      chipToCurrencyDivisor: divisor,
      currencyCode: currency,
      players: players,
    );

    final notifier = ref.read(activeGameProvider.notifier);
    notifier.startGame(session);
    // Everyone starts with one buy-in; re-buys are adjusted on the next screen.
    for (final player in players) {
      notifier.setBuyInCount(player.id, 1);
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameTableScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Game')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Chip Settings', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _chipsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Chips per buy-in',
                      helperText: 'e.g. 500',
                    ),
                    validator: (value) {
                      final n = int.tryParse(value?.trim() ?? '');
                      if (n == null || n <= 0) return 'Enter a positive number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _divisorController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Divide by',
                      helperText: 'e.g. 4',
                    ),
                    validator: (value) {
                      final n = double.tryParse(value?.trim() ?? '');
                      if (n == null || n <= 0) return 'Enter a positive number';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _currencyController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Currency code',
                helperText: 'e.g. INR, USD',
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            Text('Players', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Player name'),
                    onSubmitted: (_) => _addPlayer(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _addPlayer, icon: const Icon(Icons.add)),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _playerNames.length; i++)
              ListTile(
                title: Text(_playerNames[i]),
                leading: const Icon(Icons.person_outline),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _removePlayer(i),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _startGame,
              child: const Text('Start Game'),
            ),
          ],
        ),
      ),
    );
  }
}
