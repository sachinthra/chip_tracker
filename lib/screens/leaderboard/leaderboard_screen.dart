import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/avatar_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/leaderboard_entry.dart';
import '../../providers/people_providers.dart';
import 'person_actions.dart';
import 'person_history_screen.dart';

/// All-time standings aggregated from history games, with rename / merge /
/// recolor of people (so differently-typed names can be unified).
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: entries.isEmpty
          ? const Center(child: Text('Finish a game to build the leaderboard.'))
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _LeaderboardTile(entry: entry, rank: index + 1);
              },
            ),
    );
  }
}

class _LeaderboardTile extends ConsumerWidget {
  const _LeaderboardTile({required this.entry, required this.rank});

  final LeaderboardEntry entry;
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final net = entry.netTotal;
    final netColor = net >= 0 ? Colors.green[700] : Colors.red[700];
    final netText = '${net >= 0 ? '+' : '-'}'
        '${CurrencyFormatter.format(net.abs(), currencyCode: entry.currencyCode)}';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AvatarColors.fromHex(entry.colorHex),
        child: Text(
          '$rank',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(entry.displayName),
      subtitle: Text(
        '${entry.gamesPlayed} games · ${entry.wins} wins · '
        'best +${CurrencyFormatter.format(entry.biggestWin, currencyCode: entry.currencyCode)}',
      ),
      trailing: Text(
        netText,
        style: TextStyle(color: netColor, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PersonHistoryScreen(entry: entry)),
      ),
      onLongPress: () => PersonActions.showSheet(context, ref, entry),
    );
  }
}
