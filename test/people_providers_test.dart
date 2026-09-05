import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:track_app/models/game_session.dart';
import 'package:track_app/models/ledger_entry.dart';
import 'package:track_app/models/player.dart';
import 'package:track_app/providers/game_providers.dart';
import 'package:track_app/providers/people_providers.dart';
import 'package:track_app/services/local/local_storage_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('people_providers_test');
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  GameSession finishedGame(String winner, String loser, DateTime at) {
    final w = Player(name: winner);
    final l = Player(name: loser);
    return GameSession(
      createdAt: at,
      players: [w, l],
      ledger: [
        LedgerEntry.buyIn(playerId: w.id, chips: 500),
        LedgerEntry.buyIn(playerId: l.id, chips: 500),
        LedgerEntry.cashOut(playerId: w.id, chips: 1000),
        LedgerEntry.cashOut(playerId: l.id, chips: 0),
      ],
    );
  }

  Future<ProviderContainer> containerWithGames(List<GameSession> games) async {
    await Hive.close();
    final storage = LocalStorageService();
    await storage.initForTesting(tempDir.path);
    for (final g in games) {
      await storage.saveSession(g);
    }
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('merging two typed names combines their leaderboard rows', () async {
    final c = await containerWithGames([
      finishedGame('sachin', 'Bob', DateTime(2026, 1, 1)),
      finishedGame('sachinthra', 'Bob', DateTime(2026, 1, 2)),
    ]);

    expect(c.read(leaderboardProvider).length, 3); // sachin, sachinthra, Bob

    c.read(profilesProvider.notifier).merge(
          targetKey: 'sachin',
          targetDisplayName: 'sachin',
          targetColorHex: '#E53935',
          sourceKey: 'sachinthra',
          sourceDisplayName: 'sachinthra',
          sourceColorHex: '#3949AB',
        );

    final board = c.read(leaderboardProvider);
    expect(board.length, 2); // merged sachin + Bob
    final sachin = board.firstWhere((e) => e.displayName == 'sachin');
    expect(sachin.gamesPlayed, 2);
    expect(sachin.netTotal, closeTo(250.0, 0.001));
  });

  test('renaming updates the displayed name on the leaderboard', () async {
    final c = await containerWithGames([
      finishedGame('Alice', 'Bob', DateTime(2026, 2, 1)),
    ]);

    c.read(profilesProvider.notifier).rename('bob', 'Bobby');

    final board = c.read(leaderboardProvider);
    expect(board.any((e) => e.displayName == 'Bobby'), isTrue);
    expect(board.any((e) => e.displayName == 'Bob'), isFalse);
  });
}
