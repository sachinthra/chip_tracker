import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:track_app/providers/game_providers.dart';
import 'package:track_app/providers/settings_providers.dart';
import 'package:track_app/services/local/local_storage_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('theme_test');
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

  test('defaults to system when nothing is stored', () async {
    final container = await freshContainer();
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('chosen theme mode persists across a restart', () async {
    final c1 = await freshContainer();
    c1.read(themeModeProvider.notifier).set(ThemeMode.dark);
    expect(c1.read(themeModeProvider), ThemeMode.dark);

    final c2 = await freshContainer();
    expect(c2.read(themeModeProvider), ThemeMode.dark);
  });
}
