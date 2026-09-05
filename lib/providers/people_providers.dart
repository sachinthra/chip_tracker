import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_session.dart';
import '../models/leaderboard_entry.dart';
import '../models/person_profile.dart';
import '../services/leaderboard/leaderboard_service.dart';
import 'game_providers.dart';

PersonProfile? _profileById(List<PersonProfile> profiles, String id) {
  for (final p in profiles) {
    if (p.id == id) return p;
  }
  return null;
}

/// All saved history games. Invalidate to refresh after saving/deleting.
final historySessionsProvider = Provider<List<GameSession>>((ref) {
  return ref.watch(localStorageServiceProvider).getAllSessions();
});

/// Persistent people (merged identities). Mutations persist and refresh.
class ProfilesNotifier extends Notifier<List<PersonProfile>> {
  @override
  List<PersonProfile> build() =>
      ref.read(localStorageServiceProvider).getAllProfiles();

  /// Renames an existing profile, or creates one for a raw name if none maps
  /// to it yet (keeping the old name as an alias so history still resolves).
  void rename(String entryKey, String newName) {
    final storage = ref.read(localStorageServiceProvider);
    final existing = _profileById(state, entryKey);
    if (existing != null) {
      final updated = existing.copyWith(
        displayName: newName,
        aliases: {
          ...existing.aliases,
          PersonProfile.normalize(newName),
        }.toList(),
      );
      storage.saveProfile(updated);
    } else {
      // entryKey is a normalized raw name with no profile yet.
      final profile = PersonProfile(
        displayName: newName,
        aliases: {entryKey, PersonProfile.normalize(newName)}.toList(),
      );
      storage.saveProfile(profile);
    }
    state = storage.getAllProfiles();
  }

  void setColor(String entryKey, String colorHex, {required String displayName}) {
    final storage = ref.read(localStorageServiceProvider);
    final existing = _profileById(state, entryKey);
    final profile = existing?.copyWith(colorHex: colorHex) ??
        PersonProfile(
          displayName: displayName,
          aliases: [entryKey],
          colorHex: colorHex,
        );
    storage.saveProfile(profile);
    state = storage.getAllProfiles();
  }

  /// Merges [sourceKey] into [targetKey]: the target absorbs the source's
  /// names as aliases so both resolve to one person on the leaderboard.
  void merge({
    required String targetKey,
    required String targetDisplayName,
    required String targetColorHex,
    required String sourceKey,
    required String sourceDisplayName,
    required String sourceColorHex,
  }) {
    final storage = ref.read(localStorageServiceProvider);

    PersonProfile targetProfile =
        _profileById(state, targetKey) ??
            PersonProfile(
              displayName: targetDisplayName,
              aliases: [targetKey, PersonProfile.normalize(targetDisplayName)],
              colorHex: targetColorHex,
            );

    final sourceProfile = _profileById(state, sourceKey);
    final sourceAliases = sourceProfile?.aliases ??
        [sourceKey, PersonProfile.normalize(sourceDisplayName)];

    targetProfile = targetProfile.copyWith(
      aliases: {...targetProfile.aliases, ...sourceAliases}.toList(),
    );

    storage.saveProfile(targetProfile);
    if (sourceProfile != null) {
      storage.deleteProfile(sourceProfile.id);
    }
    state = storage.getAllProfiles();
  }
}

final profilesProvider =
    NotifierProvider<ProfilesNotifier, List<PersonProfile>>(ProfilesNotifier.new);

final leaderboardProvider = Provider<List<LeaderboardEntry>>((ref) {
  final games = ref.watch(historySessionsProvider);
  final profiles = ref.watch(profilesProvider);
  return LeaderboardService.buildLeaderboard(games: games, profiles: profiles);
});

/// Distinct names ever used, for seating autocomplete.
final knownPlayerNamesProvider = Provider<List<String>>((ref) {
  final games = ref.watch(historySessionsProvider);
  final profiles = ref.watch(profilesProvider);
  return LeaderboardService.knownNames(games: games, profiles: profiles);
});
