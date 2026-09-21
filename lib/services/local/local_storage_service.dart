import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../models/game_session.dart';
import '../../models/person_profile.dart';

/// Offline-first persistence for game sessions ("History Vault"), backed by
/// Hive. Sessions are stored as plain JSON maps so no generated TypeAdapters
/// are required.
class LocalStorageService {
  Box<Map>? _box;
  Box<Map>? _activeGameBox;
  Box? _settingsBox;
  Box<Map>? _peopleBox;

  Future<void> init() async {
    await Hive.initFlutter();
    await _openBoxes();
  }

  /// Initializes Hive against an explicit [path] instead of the platform's
  /// documents directory — used by widget tests, which have no path_provider
  /// platform channel available.
  @visibleForTesting
  Future<void> initForTesting(String path) async {
    Hive.init(path);
    await _openBoxes();
  }

  Future<void> _openBoxes() async {
    _box = await Hive.openBox<Map>(AppConstants.hiveGameSessionsBoxName);
    _activeGameBox = await Hive.openBox<Map>(AppConstants.hiveActiveGameBoxName);
    _settingsBox = await Hive.openBox(AppConstants.hiveSettingsBoxName);
    _peopleBox = await Hive.openBox<Map>(AppConstants.hivePeopleBoxName);
  }

  Box<Map> get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('LocalStorageService.init() must be called before use.');
    }
    return box;
  }

  Box<Map> get _requireActiveGameBox {
    final box = _activeGameBox;
    if (box == null) {
      throw StateError('LocalStorageService.init() must be called before use.');
    }
    return box;
  }

  Future<void> saveSession(GameSession session) async {
    await _requireBox.put(session.id, session.toJson());
  }

  List<GameSession> getAllSessions() {
    return _requireBox.values
        .map((json) => GameSession.fromJson(Map<String, dynamic>.from(json)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  GameSession? getSession(String id) {
    final json = _requireBox.get(id);
    if (json == null) return null;
    return GameSession.fromJson(Map<String, dynamic>.from(json));
  }

  Future<void> deleteSession(String id) async {
    await _requireBox.delete(id);
  }

  /// Persists the in-progress game so it survives app restarts/force-quits.
  /// Only cleared by [clearActiveGame] — never inferred/auto-deleted.
  Future<void> saveActiveGame(GameSession session) async {
    await _requireActiveGameBox.put(AppConstants.activeGameKey, session.toJson());
  }

  GameSession? getActiveGame() {
    final json = _requireActiveGameBox.get(AppConstants.activeGameKey);
    if (json == null) return null;
    return GameSession.fromJson(Map<String, dynamic>.from(json));
  }

  Future<void> clearActiveGame() async {
    await _requireActiveGameBox.delete(AppConstants.activeGameKey);
  }

  /// Persisted theme preference: 'system' | 'light' | 'dark'. Null if unset.
  String? getThemeMode() =>
      _settingsBox?.get(AppConstants.themeModeKey) as String?;

  Future<void> saveThemeMode(String mode) async {
    await _settingsBox?.put(AppConstants.themeModeKey, mode);
  }

  /// Persisted leaderboard sort metric name. Null if the user never changed it.
  String? getLeaderboardSort() =>
      _settingsBox?.get(AppConstants.leaderboardSortKey) as String?;

  Future<void> saveLeaderboardSort(String sortName) async {
    await _settingsBox?.put(AppConstants.leaderboardSortKey, sortName);
  }

  List<PersonProfile> getAllProfiles() {
    final box = _peopleBox;
    if (box == null) return [];
    return box.values
        .map((json) => PersonProfile.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<void> saveProfile(PersonProfile profile) async {
    await _peopleBox?.put(profile.id, profile.toJson());
  }

  Future<void> deleteProfile(String id) async {
    await _peopleBox?.delete(id);
  }
}
