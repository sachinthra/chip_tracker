import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/game_providers.dart';
import '../../providers/people_providers.dart';
import '../../services/backup/backup_service.dart';
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

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(backupServiceProvider).exportAndShare();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    String? contents;
    final bytes = file.bytes;
    if (bytes != null) {
      contents = utf8.decode(bytes);
    } else if (file.path != null) {
      contents = await File(file.path!).readAsString();
    }
    if (contents == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read the selected file.')),
      );
      return;
    }

    ImportSummary summary;
    try {
      summary = await ref.read(backupServiceProvider).importFromJson(contents);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
      return;
    }

    ref.invalidate(historySessionsProvider);
    ref.invalidate(profilesProvider);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import complete'),
        content: Text(
          'Games: ${summary.newGames} added, '
          '${summary.skippedGames} already present.\n'
          'People: ${summary.newPeople} added, '
          '${summary.skippedPeople} already present.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historySessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History Vault'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Backup',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') {
                _export(context, ref);
              } else if (value == 'import') {
                _import(context, ref);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('Export backup'),
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Import backup'),
                ),
              ),
            ],
          ),
        ],
      ),
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
