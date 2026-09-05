import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/currency_formatter.dart';
import '../../models/game_session.dart';
import '../../models/settlement_transaction.dart';
import '../../providers/game_providers.dart';
import '../../services/settlement/settlement_engine.dart';
import '../../widgets/game_stats_bar.dart';

/// Shows each player's result, flags any buy-in/cash-out mismatch, and lists
/// the minimal settlement transactions in a copy-paste-ready block for
/// manually adding as Splitwise expenses.
class SettlementResultScreen extends ConsumerWidget {
  const SettlementResultScreen({super.key, this.session});

  /// Pass an explicit [session] when viewing a saved game from History.
  /// Leave null to read the currently active game.
  final GameSession? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = session ?? ref.watch(activeGameProvider);
    if (activeSession == null) {
      return const Scaffold(body: Center(child: Text('No game to settle')));
    }

    final balances = SettlementEngine.computeNetBalances(activeSession);
    final transactions = SettlementEngine.simplify(balances);

    final totalBuyIn = activeSession.players
        .fold<int>(0, (sum, p) => sum + activeSession.totalBuyInChips(p.id));
    final totalCashOut = activeSession.players
        .fold<int>(0, (sum, p) => sum + activeSession.totalCashOutChips(p.id));
    final isBalanced = totalBuyIn == totalCashOut;
    final totalProfit = activeSession.players.fold<double>(0, (sum, p) {
      final net = activeSession.netResultFor(p.id);
      return sum + (net > 0 ? net : 0);
    });

    String nameFor(String playerId) =>
        activeSession.players.firstWhere((p) => p.id == playerId).name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlement'),
        bottom: GameStatsBar(
          buyInAmount: activeSession.chipsToCurrency(totalBuyIn),
          cashOutAmount: activeSession.chipsToCurrency(totalCashOut),
          totalProfit: totalProfit,
          isBalanced: isBalanced,
          diffChips: totalCashOut - totalBuyIn,
          currencyCode: activeSession.currencyCode,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isBalanced)
            Card(
              color: Colors.red.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total buy-in ($totalBuyIn chips) does not match total '
                        'cash-out ($totalCashOut chips). Double-check entries — '
                        'the settlement below may be incomplete.',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text('Player Results', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final player in activeSession.players)
            _PlayerResultTile(session: activeSession, playerId: player.id),
          const SizedBox(height: 24),
          Text('Settlement', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            const Text('No transactions needed — everyone is even.')
          else
            for (final tx in transactions)
              ListTile(
                leading: const Icon(Icons.arrow_forward),
                title: Text('${nameFor(tx.fromPlayerId)} pays ${nameFor(tx.toPlayerId)}'),
                trailing: Text(
                  CurrencyFormatter.format(tx.amount, currencyCode: activeSession.currencyCode),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy for Splitwise'),
            onPressed: () => _copySummary(context, activeSession, transactions, nameFor),
          ),
          if (session == null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save to History'),
              onPressed: () => _saveToHistory(context, ref, activeSession),
            ),
          ],
        ],
      ),
    );
  }

  String _buildSummary(
    GameSession session,
    List<SettlementTransaction> transactions,
    String Function(String) nameFor,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Poker Night Settlement — ${DateFormat.yMMMd().format(session.createdAt)}');
    buffer.writeln(
      '${session.chipsPerBuyIn} chips per buy-in, '
      '${CurrencyFormatter.format(session.chipsToCurrency(session.chipsPerBuyIn), currencyCode: session.currencyCode)} '
      'per buy-in (÷${session.chipToCurrencyDivisor.toStringAsFixed(0)})',
    );
    buffer.writeln();
    buffer.writeln('Player Results:');
    for (final player in session.players) {
      final buyIn = CurrencyFormatter.format(
        session.chipsToCurrency(session.totalBuyInChips(player.id)),
        currencyCode: session.currencyCode,
      );
      final cashOut = CurrencyFormatter.format(
        session.chipsToCurrency(session.totalCashOutChips(player.id)),
        currencyCode: session.currencyCode,
      );
      final net = session.netResultFor(player.id);
      final netFormatted = CurrencyFormatter.format(net.abs(), currencyCode: session.currencyCode);
      final sign = net >= 0 ? '+' : '-';
      buffer.writeln(
        '${player.name}: Buy-in $buyIn | Cash-out $cashOut | Net $sign$netFormatted',
      );
    }
    buffer.writeln();
    buffer.writeln('Settlement (add these as expenses in Splitwise):');
    if (transactions.isEmpty) {
      buffer.writeln('No transactions needed — everyone is even.');
    } else {
      for (final tx in transactions) {
        buffer.writeln(
          '${nameFor(tx.fromPlayerId)} pays ${nameFor(tx.toPlayerId)} '
          '${CurrencyFormatter.format(tx.amount, currencyCode: session.currencyCode)}',
        );
      }
    }
    return buffer.toString();
  }

  Future<void> _copySummary(
    BuildContext context,
    GameSession session,
    List<SettlementTransaction> transactions,
    String Function(String) nameFor,
  ) async {
    final summary = _buildSummary(session, transactions, nameFor);
    await Clipboard.setData(ClipboardData(text: summary));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    }
  }

  Future<void> _saveToHistory(
    BuildContext context,
    WidgetRef ref,
    GameSession session,
  ) async {
    final notifier = ref.read(activeGameProvider.notifier);
    notifier.markSettled();
    final settledSession = ref.read(activeGameProvider);
    if (settledSession != null) {
      await ref.read(localStorageServiceProvider).saveSession(settledSession);
    }
    notifier.clearGame();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

class _PlayerResultTile extends StatelessWidget {
  const _PlayerResultTile({required this.session, required this.playerId});

  final GameSession session;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    final player = session.players.firstWhere((p) => p.id == playerId);
    final net = session.netResultFor(playerId);
    final color = net >= 0 ? Colors.green[700] : Colors.red[700];
    final netFormatted = CurrencyFormatter.format(net.abs(), currencyCode: session.currencyCode);
    final sign = net >= 0 ? '+' : '-';

    return ListTile(
      title: Text(player.name),
      subtitle: Text(
        'Buy-in ${CurrencyFormatter.format(session.chipsToCurrency(session.totalBuyInChips(playerId)), currencyCode: session.currencyCode)} '
        '· Cash-out ${CurrencyFormatter.format(session.chipsToCurrency(session.totalCashOutChips(playerId)), currencyCode: session.currencyCode)}',
      ),
      trailing: Text(
        '$sign$netFormatted',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
