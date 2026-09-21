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
    final entries = ref.watch(sortedLeaderboardProvider);
    final sort = ref.watch(leaderboardSortProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          PopupMenuButton<LeaderboardSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (s) =>
                ref.read(leaderboardSortProvider.notifier).set(s),
            itemBuilder: (_) => [
              for (final s in LeaderboardSort.values)
                CheckedPopupMenuItem(
                  value: s,
                  checked: s == sort,
                  child: Text(s.label),
                ),
            ],
          ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(child: Text('Finish a game to build the leaderboard.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Icon(Icons.sort,
                          size: 16, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Sorted by ${sort.label}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      if (entries.any((e) => e.isProvisional))
                        Text('* provisional (<5 games)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _LeaderboardTile(
                        entry: entry,
                        rank: index + 1,
                        sort: sort,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _LeaderboardTile extends ConsumerWidget {
  const _LeaderboardTile({
    required this.entry,
    required this.rank,
    required this.sort,
  });

  final LeaderboardEntry entry;
  final int rank;
  final LeaderboardSort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final metric = _metric(context);
    final prov = entry.isProvisional ? '*' : '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AvatarColors.fromHex(entry.colorHex),
        child: Text(
          '$rank',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(entry.displayName, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${entry.gamesPlayed} games · ${entry.wins} wins · '
        'best +${CurrencyFormatter.format(entry.biggestWin, currencyCode: entry.currencyCode)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            sort == LeaderboardSort.rating ? '${metric.$1}$prov' : metric.$1,
            style: TextStyle(
              color: metric.$2,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          // Always surface the rating, even when sorting by another metric.
          if (sort != LeaderboardSort.rating)
            Text('Elo ${entry.rating.round()}$prov',
                style: theme.textTheme.bodySmall),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PersonHistoryScreen(entry: entry)),
      ),
      onLongPress: () => PersonActions.showSheet(context, ref, entry),
    );
  }

  /// (text, color) for the currently-sorted metric.
  (String, Color?) _metric(BuildContext context) {
    Color signColor(double v) => v >= 0 ? Colors.green[700]! : Colors.red[700]!;
    String signedCurrency(double v) =>
        '${v >= 0 ? '+' : '-'}'
        '${CurrencyFormatter.format(v.abs(), currencyCode: entry.currencyCode)}';

    switch (sort) {
      case LeaderboardSort.rating:
        return ('${entry.rating.round()}',
            Theme.of(context).colorScheme.primary);
      case LeaderboardSort.netTotal:
        return (signedCurrency(entry.netTotal), signColor(entry.netTotal));
      case LeaderboardSort.roi:
        return ('${entry.roi >= 0 ? '+' : '-'}${(entry.roi.abs() * 100).round()}%',
            signColor(entry.roi));
      case LeaderboardSort.winRate:
        return ('${(entry.winRate * 100).round()}%', null);
      case LeaderboardSort.gamesPlayed:
        return ('${entry.gamesPlayed}', null);
      case LeaderboardSort.avgPerGame:
        return (signedCurrency(entry.avgPerGame), signColor(entry.avgPerGame));
      case LeaderboardSort.biggestWin:
        return ('+${CurrencyFormatter.format(entry.biggestWin, currencyCode: entry.currencyCode)}',
            Colors.green[700]);
    }
  }
}
