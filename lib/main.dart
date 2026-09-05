import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/utils/currency_formatter.dart';
import 'providers/game_providers.dart';
import 'providers/people_providers.dart';
import 'providers/settings_providers.dart';
import 'providers/splitwise_providers.dart';
import 'screens/game_table/game_table_screen.dart';
import 'screens/history/history_vault_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/settings/splitwise_settings_screen.dart';
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

class PokerCompanionApp extends ConsumerWidget {
  const PokerCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Chip Tracker',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: themeMode,
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
    final splitwise = ref.watch(splitwiseConnectionProvider);
    final splitwiseName = splitwise.valueOrNull?.name;
    final leaderboard = ref.watch(leaderboardProvider);
    final topEntry = leaderboard.isNotEmpty ? leaderboard.first : null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chip Tracker'),
        actions: [
          _ThemeMenuButton(),
          IconButton(
            tooltip: splitwiseName == null
                ? 'Connect Splitwise'
                : 'Splitwise: $splitwiseName',
            icon: Icon(
              splitwiseName == null ? Icons.link_off : Icons.link,
              color: splitwiseName == null ? null : Colors.green,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SplitwiseSettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          // Hero.
          Column(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.casino,
                    size: 36, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 12),
              Text('Chip Tracker',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Track buy-ins, cash-outs & settle up',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Resume in-progress game.
          if (activeGame != null) ...[
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: const Icon(Icons.play_circle_fill, size: 36),
                title: const Text('Game in progress',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${activeGame.players.length} players · tap to resume'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GameTableScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Primary action.
          FilledButton.icon(
            onPressed: () => _startNewGame(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Start New Game'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 20),

          // Secondary actions.
          _HomeActionCard(
            icon: Icons.emoji_events_outlined,
            title: 'Leaderboard',
            subtitle: topEntry == null
                ? 'All-time standings'
                : 'Leader: ${topEntry.displayName} '
                    '(${topEntry.netTotal >= 0 ? '+' : '-'}'
                    '${CurrencyFormatter.format(topEntry.netTotal.abs(), currencyCode: topEntry.currencyCode)})',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _HomeActionCard(
            icon: Icons.history,
            title: 'History Vault',
            subtitle: 'Past games',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryVaultScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable card for a secondary home action.
class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// App-bar menu to switch between System / Light / Dark themes.
class _ThemeMenuButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Theme',
      icon: Icon(switch (mode) {
        ThemeMode.light => Icons.light_mode,
        ThemeMode.dark => Icons.dark_mode,
        ThemeMode.system => Icons.brightness_auto,
      }),
      onSelected: (m) => ref.read(themeModeProvider.notifier).set(m),
      itemBuilder: (_) => [
        _themeItem(ThemeMode.system, mode, Icons.brightness_auto, 'System'),
        _themeItem(ThemeMode.light, mode, Icons.light_mode, 'Light'),
        _themeItem(ThemeMode.dark, mode, Icons.dark_mode, 'Dark'),
      ],
    );
  }

  PopupMenuItem<ThemeMode> _themeItem(
    ThemeMode value,
    ThemeMode current,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<ThemeMode>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
          if (value == current) ...[
            const Spacer(),
            const Icon(Icons.check, size: 18),
          ],
        ],
      ),
    );
  }
}
