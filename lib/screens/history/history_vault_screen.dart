import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/game_providers.dart';
import '../settlement/settlement_result_screen.dart';

/// Past games pulled from local storage, with the ability to re-open and
/// review a session's settlement if mistakes were made.
class HistoryVaultScreen extends ConsumerWidget {
  const HistoryVaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.read(localStorageServiceProvider).getAllSessions();

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
                  title: Text(DateFormat.yMMMd().add_jm().format(session.createdAt)),
                  subtitle: Text('${session.players.length} players'),
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
