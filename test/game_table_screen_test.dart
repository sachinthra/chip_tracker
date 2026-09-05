import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:track_app/models/game_session.dart';
import 'package:track_app/models/player.dart';
import 'package:track_app/providers/game_providers.dart';
import 'package:track_app/screens/game_table/game_table_screen.dart';
import 'package:track_app/services/local/local_storage_service.dart';

void main() {
  late Directory tempDir;
  late LocalStorageService storage;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('game_table_test');
    await Hive.close();
    storage = LocalStorageService();
    await storage.initForTesting(tempDir.path);
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  testWidgets('adding a player mid-game does not crash and shows the new name',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    container
        .read(activeGameProvider.notifier)
        .startGame(GameSession(players: [Player(name: 'Alice'), Player(name: 'Bob')]));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GameTableScreen()),
      ),
    );

    expect(find.text('Alice'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_add_alt_1).first);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, 'Carl');
    await tester.tap(find.text('Add'));
    // pumpAndSettle runs the dialog dismiss animation — the old crash
    // (_dependents.isEmpty) fired here when the controller was disposed early.
    await tester.pumpAndSettle();

    expect(container.read(activeGameProvider)!.players.length, 3);
    expect(find.text('Carl'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
