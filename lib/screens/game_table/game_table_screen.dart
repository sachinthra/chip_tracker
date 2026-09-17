import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/avatar_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/game_session.dart';
import '../../models/player.dart';
import '../../providers/game_providers.dart';
import '../../providers/people_providers.dart';
import '../../widgets/cash_out_dialog.dart';
import '../../widgets/game_stats_bar.dart';
import '../../widgets/player_avatar.dart';
import '../settlement/settlement_result_screen.dart';
import '../side_games/dice_roller_screen.dart';
import '../side_games/side_pot_calculator_screen.dart';
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
  final Map<String, FocusNode> _cashOutFocusNodes = {};

  /// Player whose cash-out field is currently focused. Kept in the active list
  /// while editing so recording a value mid-typing doesn't collapse the card
  /// out from under the keyboard.
  String? _editingPlayerId;

  /// Bottom-nav tab: 0 = Table, 1 = Players, 2 = Tools.
  int _tab = 0;

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

  /// Focus node per player; while focused the player stays in the active list.
  FocusNode _focusNodeFor(String playerId) {
    return _cashOutFocusNodes.putIfAbsent(playerId, () {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          if (_editingPlayerId != playerId) {
            setState(() => _editingPlayerId = playerId);
          }
        } else if (_editingPlayerId == playerId) {
          setState(() => _editingPlayerId = null);
        }
      });
      return node;
    });
  }

  @override
  void dispose() {
    for (final controller in _cashOutControllers.values) {
      controller.dispose();
    }
    for (final node in _cashOutFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _addPlayerDialog() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddPlayerSheet(),
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

    const titles = ['Table', 'Players', 'Tools'];

    // No leave-confirmation needed: progress auto-saves, so exiting (back)
    // simply returns home with the game resumable.
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          // Calculate is irrelevant on the Tools tab.
          if (_tab != 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: FilledButton.tonal(
                onPressed: _onCalculate,
                child: const Text('Settle'),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'addplayer') {
                _addPlayerDialog();
              } else if (v == 'delete') {
                _confirmDelete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'addplayer', child: Text('Add player')),
              const PopupMenuItem(value: 'delete', child: Text('Delete game')),
            ],
          ),
        ],
        bottom: GameStatsBar(
          totalProfit: totalProfit,
          isBalanced: isBalanced,
          diffChips: diffChips,
          currencyCode: session.currencyCode,
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          const TableViewBody(),
          _buildEntryList(context, session),
          const _ToolsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.blur_circular_outlined),
            selectedIcon: Icon(Icons.blur_circular),
            label: 'Table',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Players',
          ),
          NavigationDestination(
            icon: Icon(Icons.casino_outlined),
            selectedIcon: Icon(Icons.casino),
            label: 'Tools',
          ),
        ],
      ),
    );
  }

  Widget _buildEntryList(BuildContext context, GameSession session) {
    final cashedOutCount =
        session.players.where((p) => session.hasCashedOut(p.id)).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '$cashedOutCount of ${session.players.length} cashed out',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        // Active players in entry order, then cashed-out players collapsed
        // at the bottom.
        for (final player in _activePlayers(session))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlayerEntryCard(
              session: session,
              player: player,
              cashOutController: _controllerFor(player.id, session),
              cashOutFocusNode: _focusNodeFor(player.id),
              onChanged: () => setState(() {}),
            ),
          ),
        for (final player in _cashedOut(session))
          _CashedOutTile(
            session: session,
            player: player,
            onChanged: () => setState(() {}),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _addPlayerDialog,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add Player'),
        ),
      ],
    );
  }

  List<Player> _activePlayers(GameSession session) => session.players
      .where((p) => !session.hasCashedOut(p.id) || p.id == _editingPlayerId)
      .toList();

  List<Player> _cashedOut(GameSession session) => session.players
      .where((p) => session.hasCashedOut(p.id) && p.id != _editingPlayerId)
      .toList();
}

/// Tools tab: the side utilities, made discoverable instead of hidden behind
/// unlabeled app-bar icons.
class _ToolsTab extends StatelessWidget {
  const _ToolsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.casino),
            title: const Text('Dice roller'),
            subtitle: const Text('Pick a dealer or break a tie'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiceRollerScreen()),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text('Side-pot calculator'),
            subtitle: const Text('Split an all-in pot fairly'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SidePotCalculatorScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerEntryCard extends ConsumerWidget {
  const _PlayerEntryCard({
    required this.session,
    required this.player,
    required this.cashOutController,
    required this.cashOutFocusNode,
    required this.onChanged,
  });

  final GameSession session;
  final Player player;
  final TextEditingController cashOutController;
  final FocusNode cashOutFocusNode;
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
    // (e.g. the table view) shows here — but never while the user is typing in
    // it, or we'd fight their keystrokes and jump the cursor.
    if (!cashOutFocusNode.hasFocus) {
      final desiredText =
          hasCashedOut ? session.totalCashOutChips(player.id).toString() : '';
      if (cashOutController.text != desiredText) {
        cashOutController.value = TextEditingValue(
          text: desiredText,
          selection: TextSelection.collapsed(offset: desiredText.length),
        );
      }
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
              focusNode: cashOutFocusNode,
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

/// Compact row for a player who has cashed out — declutters the list. Tap to
/// edit their final chip count or move them back to "still playing".
class _CashedOutTile extends ConsumerWidget {
  const _CashedOutTile({
    required this.session,
    required this.player,
    required this.onChanged,
  });

  final GameSession session;
  final Player player;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final net = session.netResultFor(player.id);
    final netColor = net >= 0 ? Colors.green[700] : Colors.red[700];
    final netText = '${net >= 0 ? '+' : '-'}'
        '${CurrencyFormatter.format(net.abs(), currencyCode: session.currencyCode)}';

    return Card(
      child: ListTile(
        dense: true,
        leading: PlayerAvatar(player: player, radius: 14),
        title: Text(player.name),
        subtitle: Text('Cashed out ${session.totalCashOutChips(player.id)} chips'),
        trailing: Text(
          netText,
          style: TextStyle(color: netColor, fontWeight: FontWeight.bold),
        ),
        onTap: () => _showActions(context, ref),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit cash-out'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final chips = await showDialog<int>(
                  context: context,
                  builder: (_) => CashOutDialog(
                    playerName: player.name,
                    initialChips: session.totalCashOutChips(player.id),
                  ),
                );
                if (chips != null) {
                  ref.read(activeGameProvider.notifier).recordCashOut(player.id, chips);
                  onChanged();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Still playing'),
              onTap: () {
                ref.read(activeGameProvider.notifier).clearCashOut(player.id);
                Navigator.of(sheetContext).pop();
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Add-player bottom sheet: a search field that filters past players as you
/// type, over a scrollable list. Resizes above the keyboard and scales to any
/// number of regulars (fixing the old dialog's overflow). Returns the chosen
/// or typed name via [Navigator.pop].
class _AddPlayerSheet extends ConsumerStatefulWidget {
  const _AddPlayerSheet();

  @override
  ConsumerState<_AddPlayerSheet> createState() => _AddPlayerSheetState();
}

class _AddPlayerSheetState extends ConsumerState<_AddPlayerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String name) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final seated = ref
            .watch(activeGameProvider)
            ?.players
            .map((p) => p.name.toLowerCase())
            .toSet() ??
        <String>{};
    final all = ref
        .watch(knownPlayerNamesProvider)
        .where((n) => !seated.contains(n.toLowerCase()))
        .toList();
    final query = _query.trim();
    final q = query.toLowerCase();
    final filtered =
        q.isEmpty ? all : all.where((n) => n.toLowerCase().contains(q)).toList();
    final exactMatch = all.any((n) => n.toLowerCase() == q);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const Key('addPlayerField'),
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Player name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: _add,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView(
              shrinkWrap: true,
              children: [
                if (query.isNotEmpty && !exactMatch)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.add)),
                    title: Text('Add "$query"'),
                    onTap: () => _add(query),
                  ),
                for (final name in filtered)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AvatarColors.fromHex(
                        AvatarColors.palette[
                            name.hashCode.abs() % AvatarColors.palette.length],
                      ),
                      child: Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(name),
                    onTap: () => _add(name),
                  ),
                if (filtered.isEmpty && query.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No past players yet — type a name above.'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
