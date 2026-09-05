import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/avatar_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/leaderboard_entry.dart';
import '../../providers/people_providers.dart';
import '../../services/leaderboard/leaderboard_service.dart';
import 'person_actions.dart';

/// Every game a person played, with the net result and the exact name typed
/// that night (useful for spotting aliases to merge).
class PersonHistoryScreen extends ConsumerWidget {
  const PersonHistoryScreen({super.key, required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(historySessionsProvider);
    final profiles = ref.watch(profilesProvider);
    final results = LeaderboardService.gamesForPerson(
      entryKey: entry.key,
      games: games,
      profiles: profiles,
    );

    // The display name/color can change via the actions menu; re-resolve from
    // the live leaderboard so this screen reflects edits immediately.
    final live = ref.watch(leaderboardProvider).where((e) => e.key == entry.key);
    final current = live.isNotEmpty ? live.first : entry;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AvatarColors.fromHex(current.colorHex),
            ),
            const SizedBox(width: 8),
            Text(current.displayName),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'rename':
                  PersonActions.rename(context, ref, current);
                case 'merge':
                  PersonActions.merge(context, ref, current);
                case 'color':
                  PersonActions.changeColor(context, ref, current);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'merge', child: Text('Combine with…')),
              PopupMenuItem(value: 'color', child: Text('Change color')),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Net ${current.netTotal >= 0 ? '+' : '-'}'
              '${CurrencyFormatter.format(current.netTotal.abs(), currencyCode: current.currencyCode)} '
              'over ${current.gamesPlayed} games',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          for (final result in results)
            ListTile(
              title: Text(DateFormat.yMMMd().format(result.playedAt)),
              subtitle: result.nameUsed != current.displayName
                  ? Text('played as "${result.nameUsed}"')
                  : null,
              trailing: Text(
                '${result.net >= 0 ? '+' : '-'}'
                '${CurrencyFormatter.format(result.net.abs(), currencyCode: result.currencyCode)}',
                style: TextStyle(
                  color: result.net >= 0 ? Colors.green[700] : Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
