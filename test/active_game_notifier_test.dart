import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:track_app/models/game_session.dart';
import 'package:track_app/models/player.dart';
import 'package:track_app/providers/game_providers.dart';
import 'package:track_app/services/local/local_storage_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('active_game_test');
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  Future<ProviderContainer> freshContainer() async {
    await Hive.close();
    final storage = LocalStorageService();
    await storage.initForTesting(tempDir.path);
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('cash-out for an early leaver persists across a restart', () async {
    final alice = Player(name: 'Alice');
    final bob = Player(name: 'Bob');

    final c1 = await freshContainer();
    final notifier = c1.read(activeGameProvider.notifier);
    notifier.startGame(GameSession(players: [alice, bob]));
    notifier.setBuyInCount(alice.id, 1);
    notifier.setBuyInCount(bob.id, 1);
    // Alice leaves early cashing out 300 chips.
    notifier.recordCashOut(alice.id, 300);

    // Simulate app restart: new container reading from the same Hive dir.
    final c2 = await freshContainer();
    final restored = c2.read(activeGameProvider);

    expect(restored, isNotNull);
    expect(restored!.hasCashedOut(alice.id), isTrue);
    expect(restored.totalCashOutChips(alice.id), 300);
    expect(restored.hasCashedOut(bob.id), isFalse);
  });

  test('adding a player mid-game persists across a restart', () async {
    final alice = Player(name: 'Alice');

    final c1 = await freshContainer();
    final notifier = c1.read(activeGameProvider.notifier);
    notifier.startGame(GameSession(players: [alice]));
    notifier.setBuyInCount(alice.id, 1);
    final lateId = notifier.addPlayer('Carl');

    final c2 = await freshContainer();
    final restored = c2.read(activeGameProvider);

    expect(restored!.players.length, 2);
    expect(restored.players.any((p) => p.name == 'Carl'), isTrue);
    // Late joiner gets one buy-in by default.
    expect(restored.totalBuyInChips(lateId!), restored.chipsPerBuyIn);
  });

  test('adding a duplicate name is rejected', () async {
    final alice = Player(name: 'Alice');
    final c1 = await freshContainer();
    final notifier = c1.read(activeGameProvider.notifier);
    notifier.startGame(GameSession(players: [alice]));

    expect(notifier.addPlayer('alice'), isNull); // case-insensitive
    expect(c1.read(activeGameProvider)!.players.length, 1);
  });

  test('removing a player deletes them and their ledger entries', () async {
    final alice = Player(name: 'Alice');
    final bob = Player(name: 'Bob');

    final c1 = await freshContainer();
    final notifier = c1.read(activeGameProvider.notifier);
    notifier.startGame(GameSession(players: [alice, bob]));
    notifier.setBuyInCount(alice.id, 1);
    notifier.setBuyInCount(bob.id, 2);
    notifier.recordCashOut(bob.id, 500);
    notifier.removePlayer(bob.id);

    final session = c1.read(activeGameProvider)!;
    expect(session.players.length, 1);
    expect(session.players.single.id, alice.id);
    expect(session.totalBuyInChips(bob.id), 0);
    expect(session.hasCashedOut(bob.id), isFalse);
  });

  test('clearing a cash-out removes the cashed-out state', () async {
    final alice = Player(name: 'Alice');

    final c1 = await freshContainer();
    final notifier = c1.read(activeGameProvider.notifier);
    notifier.startGame(GameSession(players: [alice]));
    notifier.recordCashOut(alice.id, 200);
    expect(c1.read(activeGameProvider)!.hasCashedOut(alice.id), isTrue);

    notifier.clearCashOut(alice.id);
    expect(c1.read(activeGameProvider)!.hasCashedOut(alice.id), isFalse);
  });

  test('moveBuyIn shifts one stack from giver to receiver', () async {
    final alice = Player(name: 'Alice');
    final bob = Player(name: 'Bob');

    final c1 = await freshContainer();
    final notifier = c1.read(activeGameProvider.notifier);
    notifier.startGame(GameSession(players: [alice, bob]));
    notifier.setBuyInCount(alice.id, 3); // 1500 chips
    notifier.setBuyInCount(bob.id, 1); // 500 chips

    final moved = notifier.moveBuyIn(alice.id, bob.id);
    expect(moved, isTrue);

    final s = c1.read(activeGameProvider)!;
    expect(s.totalBuyInChips(alice.id), 1000); // 3 -> 2 buy-ins
    expect(s.totalBuyInChips(bob.id), 1000); // 1 -> 2 buy-ins
  });

  test('moveBuyIn fails when the giver has no stack to give', () async {
    final alice = Player(name: 'Alice');
    final bob = Player(name: 'Bob');

    final c1 = await freshContainer();
    final notifier = c1.read(activeGameProvider.notifier);
    notifier.startGame(GameSession(players: [alice, bob]));
    notifier.setBuyInCount(alice.id, 1);
    notifier.setBuyInCount(bob.id, 1);
    // Alice already gave her chips away (stack below one buy-in).
    notifier.moveBuyIn(alice.id, bob.id); // Alice now 0 buy-ins, 0 chips

    final again = notifier.moveBuyIn(alice.id, bob.id);
    expect(again, isFalse);
    expect(c1.read(activeGameProvider)!.totalBuyInChips(bob.id), 1000);
  });
}
