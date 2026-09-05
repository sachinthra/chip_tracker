import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:track_app/main.dart';
import 'package:track_app/providers/game_providers.dart';
import 'package:track_app/services/local/local_storage_service.dart';

void main() {
  late Directory tempDir;
  late LocalStorageService storage;

  // Real dart:io calls must happen outside testWidgets' fake-async zone,
  // otherwise Hive's file I/O never completes and the test hangs.
  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('track_app_test');
    storage = LocalStorageService();
    await storage.initForTesting(tempDir.path);
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  testWidgets('Home screen shows entry points', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
        ],
        child: const PokerCompanionApp(),
      ),
    );

    expect(find.text('Start New Game'), findsOneWidget);
    expect(find.text('History Vault'), findsOneWidget);

    await tester.tap(find.text('Start New Game'));
    await tester.pumpAndSettle();

    expect(find.text('New Game'), findsWidgets);
    expect(find.text('Chip Settings'), findsOneWidget);
  });
}
