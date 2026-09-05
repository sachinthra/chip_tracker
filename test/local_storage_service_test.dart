import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:chip_tracker/models/game_session.dart';
import 'package:chip_tracker/models/ledger_entry.dart';
import 'package:chip_tracker/models/player.dart';
import 'package:chip_tracker/services/local/local_storage_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('local_storage_test');
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  // Boxes cache values in memory, so reading right after a write in the same
  // process doesn't exercise real (de)serialization. Close and reopen Hive
  // against the same directory to simulate an actual app restart.
  Future<LocalStorageService> restartStorage() async {
    await Hive.close();
    final storage = LocalStorageService();
    await storage.initForTesting(tempDir.path);
    return storage;
  }

  test('active game with real players and ledger survives an app restart', () async {
    final alice = Player(name: 'Alice');
    final bob = Player(name: 'Bob');
    final session = GameSession(
      players: [alice, bob],
      ledger: [
        LedgerEntry.buyIn(playerId: alice.id, chips: 500),
        LedgerEntry.buyIn(playerId: bob.id, chips: 500),
        LedgerEntry.loan(lenderId: alice.id, borrowerId: bob.id, chips: 500),
      ],
    );

    final writer = await restartStorage();
    await writer.saveActiveGame(session);

    final reader = await restartStorage();
    final restored = reader.getActiveGame();

    expect(restored, isNotNull);
    expect(restored!.players.length, 2);
    expect(restored.players.first.name, 'Alice');
    expect(restored.ledger.length, 3);
  });

  test('history session with real players and ledger survives an app restart', () async {
    final alice = Player(name: 'Alice');
    final bob = Player(name: 'Bob');
    final session = GameSession(
      players: [alice, bob],
      ledger: [
        LedgerEntry.buyIn(playerId: alice.id, chips: 500),
        LedgerEntry.cashOut(playerId: alice.id, chips: 500),
      ],
    );

    final writer = await restartStorage();
    await writer.saveSession(session);

    final reader = await restartStorage();
    final restored = reader.getSession(session.id);

    expect(restored, isNotNull);
    expect(restored!.players.length, 2);
    expect(restored.ledger.length, 2);
  });
}
