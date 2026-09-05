import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/game_session.dart';
import '../../models/person_profile.dart';
import '../local/local_storage_service.dart';

/// Outcome of an import, used to reassure the user which items were added
/// versus already present (so re-importing the same file is safe).
class ImportSummary {
  const ImportSummary({
    required this.newGames,
    required this.skippedGames,
    required this.newPeople,
    required this.skippedPeople,
  });

  final int newGames;
  final int skippedGames;
  final int newPeople;
  final int skippedPeople;
}

/// Exports history + people to a portable JSON file and imports them back,
/// de-duplicating by stable id so the same backup can be applied repeatedly
/// (or across a reinstall / new app id) without creating duplicates.
class BackupService {
  BackupService(this._storage);

  final LocalStorageService _storage;

  static const String appTag = 'chip_tracker';
  static const int schemaVersion = 1;

  Map<String, dynamic> buildBackup() {
    return {
      'app': appTag,
      'schema': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'sessions': _storage.getAllSessions().map((s) => s.toJson()).toList(),
      'profiles': _storage.getAllProfiles().map((p) => p.toJson()).toList(),
    };
  }

  /// Writes the backup to a temp file and opens the system share sheet.
  Future<void> exportAndShare() async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(buildBackup());
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/chip_tracker_backup_$stamp.json');
    await file.writeAsString(jsonStr);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Chip Tracker backup',
    );
  }

  /// Parses [raw] JSON and merges its games/people into local storage,
  /// skipping anything whose id already exists.
  Future<ImportSummary> importFromJson(String raw) async {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('This file is not a Chip Tracker backup.');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (map['app'] != appTag) {
      throw const FormatException('This file is not a Chip Tracker backup.');
    }

    final existingSessionIds =
        _storage.getAllSessions().map((s) => s.id).toSet();
    var newGames = 0;
    var skippedGames = 0;
    for (final raw in (map['sessions'] as List<dynamic>? ?? const [])) {
      final session =
          GameSession.fromJson(Map<String, dynamic>.from(raw as Map));
      if (existingSessionIds.contains(session.id)) {
        skippedGames++;
        continue;
      }
      await _storage.saveSession(session);
      existingSessionIds.add(session.id);
      newGames++;
    }

    final existingProfileIds =
        _storage.getAllProfiles().map((p) => p.id).toSet();
    var newPeople = 0;
    var skippedPeople = 0;
    for (final raw in (map['profiles'] as List<dynamic>? ?? const [])) {
      final profile =
          PersonProfile.fromJson(Map<String, dynamic>.from(raw as Map));
      if (existingProfileIds.contains(profile.id)) {
        skippedPeople++;
        continue;
      }
      await _storage.saveProfile(profile);
      existingProfileIds.add(profile.id);
      newPeople++;
    }

    return ImportSummary(
      newGames: newGames,
      skippedGames: skippedGames,
      newPeople: newPeople,
      skippedPeople: skippedPeople,
    );
  }
}
