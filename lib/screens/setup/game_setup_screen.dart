import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/avatar_colors.dart';
import '../../models/game_session.dart';
import '../../models/player.dart';
import '../../providers/game_providers.dart';
import '../../providers/people_providers.dart';
import '../../providers/splitwise_providers.dart';
import '../../widgets/player_avatar.dart';
import '../game_table/game_table_screen.dart';
import 'splitwise_picker_screen.dart';

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

  final List<Player> _players = [];
  String? _splitwiseGroupId;
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
    _addNamedPlayer(_nameController.text);
    _nameController.clear();
  }

  void _addNamedPlayer(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return;
    if (_players.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
      setState(() => _error = 'A player named "$name" is already added.');
      return;
    }
    setState(() {
      _players.add(Player(
        name: name,
        avatarColorHex: AvatarColors.next(_players.map((p) => p.avatarColorHex)),
      ));
      _error = null;
    });
  }

  void _removePlayer(int index) {
    setState(() => _players.removeAt(index));
  }

  Future<void> _importFromSplitwise() async {
    final result = await Navigator.of(context).push<SplitwiseImport>(
      MaterialPageRoute(builder: (_) => const SplitwisePickerScreen()),
    );
    if (result == null) return;
    setState(() {
      _splitwiseGroupId = result.groupId;
      final existingIds = _players
          .map((p) => p.splitwiseUserId)
          .whereType<String>()
          .toSet();
      for (final player in result.players) {
        final dupName =
            _players.any((p) => p.name.toLowerCase() == player.name.toLowerCase());
        if (!existingIds.contains(player.splitwiseUserId) && !dupName) {
          _players.add(player.copyWith(
            avatarColorHex:
                AvatarColors.next(_players.map((p) => p.avatarColorHex)),
          ));
        }
      }
      _error = null;
    });
  }

  void _startGame() {
    if (!_formKey.currentState!.validate()) return;
    if (_players.length < 2) {
      setState(() => _error = 'Add at least 2 players to start a game.');
      return;
    }

    final chips = int.parse(_chipsController.text.trim());
    final divisor = double.parse(_divisorController.text.trim());
    final currency = _currencyController.text.trim().toUpperCase();
    final players = List<Player>.from(_players);

    final session = GameSession(
      chipsPerBuyIn: chips,
      chipToCurrencyDivisor: divisor,
      currencyCode: currency,
      players: players,
      splitwiseGroupId: _splitwiseGroupId,
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
            if (ref.watch(splitwiseConnectionProvider).valueOrNull != null) ...[
              OutlinedButton.icon(
                onPressed: _importFromSplitwise,
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Import from Splitwise'),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Player name',
                      prefixIcon: Icon(Icons.search),
                    ),
                    // Rebuild so the suggestions filter as the user types.
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _addPlayer(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _addPlayer, icon: const Icon(Icons.add)),
              ],
            ),
            _SuggestionChips(
              query: _nameController.text,
              seatedNames: _players.map((p) => p.name).toList(),
              onPick: _addNamedPlayer,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _players.length; i++)
              ListTile(
                title: Text(_players[i].name),
                leading: PlayerAvatar(player: _players[i], radius: 16),
                subtitle: _players[i].isGhost ? null : const Text('Splitwise'),
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

/// Tappable chips of previously-seen player names not yet seated this game.
/// Filters/sorts by [query] (prefix matches first) so any past player can be
/// found by typing, instead of having to retype a full name.
class _SuggestionChips extends ConsumerWidget {
  const _SuggestionChips({
    required this.query,
    required this.seatedNames,
    required this.onPick,
  });

  final String query;
  final List<String> seatedNames;
  final void Function(String name) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seated = seatedNames.map((n) => n.toLowerCase()).toSet();
    final q = query.trim().toLowerCase();

    var names = ref
        .watch(knownPlayerNamesProvider)
        .where((n) => !seated.contains(n.toLowerCase()))
        .toList();
    if (q.isNotEmpty) {
      names = names.where((n) => n.toLowerCase().contains(q)).toList()
        ..sort((a, b) {
          final ap = a.toLowerCase().startsWith(q) ? 0 : 1;
          final bp = b.toLowerCase().startsWith(q) ? 0 : 1;
          if (ap != bp) return ap - bp;
          return a.toLowerCase().compareTo(b.toLowerCase());
        });
    }
    final suggestions = names.take(q.isEmpty ? 12 : 20).toList();
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final name in suggestions)
            ActionChip(
              avatar: const Icon(Icons.person_add_alt, size: 18),
              label: Text(name),
              onPressed: () => onPick(name),
            ),
        ],
      ),
    );
  }
}
