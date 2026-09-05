import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/game_providers.dart';
import '../../providers/people_providers.dart';
import '../settlement/settlement_result_screen.dart';

/// Past games pulled from local storage, with the ability to re-open a
/// session's settlement or delete it.
class HistoryVaultScreen extends ConsumerWidget {
  const HistoryVaultScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this game?'),
        content: const Text('This removes it from history permanently.'),
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
      await ref.read(localStorageServiceProvider).deleteSession(sessionId);
      ref.invalidate(historySessionsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historySessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History Vault')),
      body: sessions.isEmpty
          ? const Center(child: Text('No past games yet'))
          : ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(
                    DateFormat.yMMMd().add_jm().format(session.createdAt),
                  ),
                  subtitle: Text('${session.players.length} players'),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, session.id),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettlementResultScreen(session: session),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
