import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/currency_formatter.dart';
import '../../models/game_session.dart';
import '../../models/player.dart';
import '../../providers/game_providers.dart';
import '../../providers/people_providers.dart';
import '../../widgets/game_stats_bar.dart';
import '../../widgets/player_avatar.dart';
import '../settlement/settlement_result_screen.dart';
import 'table_view_screen.dart';

/// Enter each player's buy-ins and, at the end of the night, their final
/// chip count. Drag-and-drop lending comes later — for now this is a manual
/// entry screen that keeps a live running total so mismatches show up early.
class GameTableScreen extends ConsumerStatefulWidget {
  const GameTableScreen({super.key});

  @override
  ConsumerState<GameTableScreen> createState() => _GameTableScreenState();
}

class _GameTableScreenState extends ConsumerState<GameTableScreen> {
  final Map<String, TextEditingController> _cashOutControllers = {};

  /// Returns the cash-out controller for [playerId], seeding it once from the
  /// persisted cash-out value so early-leavers' amounts survive a restart.
  TextEditingController _controllerFor(String playerId, GameSession session) {
    return _cashOutControllers.putIfAbsent(playerId, () {
      final controller = TextEditingController();
      if (session.hasCashedOut(playerId)) {
        controller.text = session.totalCashOutChips(playerId).toString();
      }
      return controller;
    });
  }

  @override
  void dispose() {
    for (final controller in _cashOutControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _addPlayerDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddPlayerDialog(),
    );
    if (name == null || name.isEmpty) return;
    final id = ref.read(activeGameProvider.notifier).addPlayer(name);
    if (id == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A player named "$name" is already at the table.')),
      );
    }
  }

  void _onCalculate() {
    // The game is always kept in the History Vault; tally time is a natural
    // save point so it shows up even before the user taps "Finish".
    ref.read(activeGameProvider.notifier).saveToHistory();
    ref.invalidate(historySessionsProvider);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettlementResultScreen()),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Game?'),
        content: const Text(
          'This permanently removes the in-progress game. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(activeGameProvider.notifier).clearGame();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeGameProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active game')));
    }

    // Cash-outs are persisted live, so totals come straight from the session.
    final totalBuyInChips =
        session.players.fold<int>(0, (sum, p) => sum + session.totalBuyInChips(p.id));
    final totalCashOutChips =
        session.players.fold<int>(0, (sum, p) => sum + session.totalCashOutChips(p.id));
    final diffChips = totalCashOutChips - totalBuyInChips;
    final isBalanced = diffChips == 0;
    final totalProfit = session.players.fold<double>(0, (sum, p) {
      final net = session.netResultFor(p.id);
      return sum + (net > 0 ? net : 0);
    });
    final cashedOutCount =
        session.players.where((p) => session.hasCashedOut(p.id)).length;

    // No leave-confirmation needed: progress auto-saves, so exiting (back)
    // simply returns home with the game resumable.
    return Scaffold(
        appBar: AppBar(
          title: const Text('Game Table'),
          actions: [
            IconButton(
              tooltip: 'Table view',
              icon: const Icon(Icons.blur_circular),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TableViewScreen()),
              ),
            ),
            IconButton(
              tooltip: 'Add player',
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: _addPlayerDialog,
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') _confirmDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete game'),
                ),
              ],
            ),
          ],
          bottom: GameStatsBar(
            buyInAmount: session.chipsToCurrency(totalBuyInChips),
            cashOutAmount: session.chipsToCurrency(totalCashOutChips),
            totalProfit: totalProfit,
            isBalanced: isBalanced,
            diffChips: diffChips,
            currencyCode: session.currencyCode,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '$cashedOutCount of ${session.players.length} cashed out',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            for (final player in session.players)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlayerEntryCard(
                  session: session,
                  player: player,
                  cashOutController: _controllerFor(player.id, session),
                  onChanged: () => setState(() {}),
                ),
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _addPlayerDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Player'),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _onCalculate,
              child: const Text('Calculate Settlement'),
            ),
          ),
        ),
    );
  }
}

class _PlayerEntryCard extends ConsumerWidget {
  const _PlayerEntryCard({
    required this.session,
    required this.player,
    required this.cashOutController,
    required this.onChanged,
  });

  final GameSession session;
  final Player player;
  final TextEditingController cashOutController;
  final VoidCallback onChanged;

  void _commitCashOut(WidgetRef ref, String value) {
    final notifier = ref.read(activeGameProvider.notifier);
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      notifier.clearCashOut(player.id);
    } else {
      notifier.recordCashOut(player.id, int.tryParse(trimmed) ?? 0);
    }
    onChanged();
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${player.name}?'),
        content: const Text(
          'This deletes their buy-ins and cash-out from this game.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(activeGameProvider.notifier).removePlayer(player.id);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buyInCount = session.totalBuyInChips(player.id) ~/ session.chipsPerBuyIn;
    final buyInChips = session.totalBuyInChips(player.id);
    final buyInAmount = CurrencyFormatter.format(
      session.chipsToCurrency(buyInChips),
      currencyCode: session.currencyCode,
    );
    final hasCashedOut = session.hasCashedOut(player.id);
    final net = session.netResultFor(player.id);
    final netColor = net >= 0 ? Colors.green[700] : Colors.red[700];
    final netFormatted = CurrencyFormatter.format(
      net.abs(),
      currencyCode: session.currencyCode,
    );

    // Keep the field in sync with the session so a cash-out entered elsewhere
    // (e.g. the table view) shows here. Safe during typing: keystrokes commit
    // to the session immediately, so the two only differ on an external change.
    final desiredText =
        hasCashedOut ? session.totalCashOutChips(player.id).toString() : '';
    if (cashOutController.text != desiredText) {
      cashOutController.value = TextEditingValue(
        text: desiredText,
        selection: TextSelection.collapsed(offset: desiredText.length),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PlayerAvatar(player: player, radius: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    player.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (hasCashedOut)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Chip(
                      label: const Text('Cashed out'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.green.withValues(alpha: 0.15),
                      side: BorderSide.none,
                    ),
                  ),
                IconButton(
                  tooltip: 'Remove player',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => _confirmRemove(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Buy-ins:'),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: buyInCount > 0
                      ? () {
                          ref
                              .read(activeGameProvider.notifier)
                              .setBuyInCount(player.id, buyInCount - 1);
                          onChanged();
                        }
                      : null,
                ),
                Text('$buyInCount', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    ref
                        .read(activeGameProvider.notifier)
                        .setBuyInCount(player.id, buyInCount + 1);
                    onChanged();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('= $buyInChips chips ($buyInAmount)')),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cashOutController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Final chip count (cash-out)',
                helperText: hasCashedOut
                    ? 'Net ${net >= 0 ? '+' : '-'}$netFormatted'
                    : 'Enter when they leave / at the end',
                helperStyle: hasCashedOut
                    ? TextStyle(color: netColor, fontWeight: FontWeight.bold)
                    : null,
                border: const OutlineInputBorder(),
                suffixIcon: hasCashedOut
                    ? IconButton(
                        tooltip: 'Still playing',
                        icon: const Icon(Icons.undo),
                        onPressed: () {
                          cashOutController.clear();
                          _commitCashOut(ref, '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => _commitCashOut(ref, value),
            ),
          ],
        ),
      ),
    );
  }
}

/// Name-entry dialog for seating a new player. Owns its own controller so it
/// is disposed only after the route is fully removed (avoids the
/// "_dependents.isEmpty" assertion from disposing while still mounted).
class _AddPlayerDialog extends StatefulWidget {
  const _AddPlayerDialog();

  @override
  State<_AddPlayerDialog> createState() => _AddPlayerDialogState();
}

class _AddPlayerDialogState extends State<_AddPlayerDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Player'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Player name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
