import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/game_providers.dart';
import 'screens/game_table/game_table_screen.dart';
import 'screens/history/history_vault_screen.dart';
import 'screens/setup/game_setup_screen.dart';
import 'services/local/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localStorageService = LocalStorageService();
  await localStorageService.init();

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorageService),
      ],
      child: const PokerCompanionApp(),
    ),
  );
}

class PokerCompanionApp extends StatelessWidget {
  const PokerCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker Companion',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _startNewGame(BuildContext context, WidgetRef ref) async {
    final activeGame = ref.read(activeGameProvider);
    if (activeGame != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard current game?'),
          content: Text(
            'You have a game in progress with ${activeGame.players.length} '
            'players. Starting a new one will delete it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Discard & Start New'),
            ),
          ],
        ),
      );
      if (discard != true) return;
      ref.read(activeGameProvider.notifier).clearGame();
    }
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GameSetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGame = ref.watch(activeGameProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Poker Companion')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activeGame != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Game in progress · ${activeGame.players.length} players'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const GameTableScreen()),
                        ),
                        child: const Text('Resume Game'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            OutlinedButton(
              onPressed: () => _startNewGame(context, ref),
              child: const Text('Start New Game'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryVaultScreen()),
              ),
              child: const Text('History Vault'),
            ),
          ],
        ),
      ),
    );
  }
}
