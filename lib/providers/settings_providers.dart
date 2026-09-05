import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_providers.dart';

/// Holds the app's theme preference (system/light/dark), persisted locally.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.read(localStorageServiceProvider).getThemeMode();
    return _parse(stored);
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(localStorageServiceProvider).saveThemeMode(mode.name);
  }

  static ThemeMode _parse(String? name) {
    switch (name) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
