import 'dart:math' as math;

import '../../models/game_session.dart';
import '../../models/leaderboard_entry.dart';
import '../../models/person_profile.dart';

/// Aggregates completed history games into leaderboard rows and per-person
/// history, resolving typed player names through [PersonProfile] aliases so
/// merged identities (e.g. "sachin" == "sachinthra") count as one person.
class LeaderboardService {
  /// A game counts toward stats once at least one player has cashed out.
  static bool isComplete(GameSession session) =>
      session.players.any((p) => session.hasCashedOut(p.id));

  static const double _startElo = 1000;
  static const double _kFactor = 32;

  static List<LeaderboardEntry> buildLeaderboard({
    required List<GameSession> games,
    required List<PersonProfile> profiles,
  }) {
    final aliasToProfile = _aliasIndex(profiles);
    final acc = <String, _Agg>{};
    final elo = <String, double>{};

    // Elo is sequential, so replay games oldest-first (the history list itself
    // is newest-first). Sums are order-independent, so this is safe for them too.
    final ordered = [...games]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final game in ordered) {
      if (!isComplete(game)) continue;

      // Each participating key's net (currency) for THIS game.
      final parts = <String, double>{};
      for (final player in game.players) {
        if (!game.hasCashedOut(player.id)) continue;
        final profile = aliasToProfile[PersonProfile.normalize(player.name)];
        final key = profile?.id ?? PersonProfile.normalize(player.name);
        final net = game.netResultFor(player.id);
        parts[key] = (parts[key] ?? 0) + net;

        final agg = acc.putIfAbsent(
          key,
          () => _Agg(
            key: key,
            displayName: profile?.displayName ?? player.name,
            colorHex: profile?.colorHex ?? player.avatarColorHex,
            photoPath: profile?.photoPath,
            currencyCode: game.currencyCode,
          ),
        );
        agg.gamesPlayed += 1;
        agg.netTotal += net;
        agg.totalBuyIn += game.chipsToCurrency(game.totalBuyInChips(player.id));
        if (net > 0.009) {
          agg.wins += 1;
          if (net > agg.biggestWin) agg.biggestWin = net;
        }
      }

      _applyElo(elo, parts);
    }

    final entries = acc.values.map((a) {
      final raw = elo[a.key] ?? _startElo;
      // Shrink toward the baseline until the person has enough games, so a
      // 1-2 game hot streak can't outrank a proven regular.
      final confidence =
          (a.gamesPlayed / LeaderboardEntry.provisionalThreshold).clamp(0.0, 1.0);
      final rating = _startElo + (raw - _startElo) * confidence;
      return LeaderboardEntry(
        key: a.key,
        displayName: a.displayName,
        colorHex: a.colorHex,
        photoPath: a.photoPath,
        currencyCode: a.currencyCode,
        gamesPlayed: a.gamesPlayed,
        wins: a.wins,
        netTotal: a.netTotal,
        biggestWin: a.biggestWin,
        totalBuyIn: a.totalBuyIn,
        rawElo: raw,
        rating: rating,
        isProvisional:
            a.gamesPlayed < LeaderboardEntry.provisionalThreshold,
      );
    }).toList();

    entries.sort((a, b) => b.rating.compareTo(a.rating));
    return entries;
  }

  /// Multiplayer Elo: rank [parts] by net, then run a pairwise update so each
  /// player gains/loses points versus every opponent based on the result.
  static void _applyElo(Map<String, double> elo, Map<String, double> parts) {
    final keys = parts.keys.toList();
    if (keys.length < 2) return;
    final delta = <String, double>{};
    for (final i in keys) {
      final ri = elo[i] ?? _startElo;
      var d = 0.0;
      for (final j in keys) {
        if (i == j) continue;
        final rj = elo[j] ?? _startElo;
        final expected = 1 / (1 + math.pow(10, (rj - ri) / 400));
        final actual = parts[i]! > parts[j]!
            ? 1.0
            : parts[i]! < parts[j]!
                ? 0.0
                : 0.5;
        d += actual - expected;
      }
      delta[i] = d;
    }
    for (final i in keys) {
      elo[i] = (elo[i] ?? _startElo) + _kFactor / (keys.length - 1) * delta[i]!;
    }
  }

  /// Every game the person identified by [entryKey] appeared in, newest first.
  static List<PersonGameResult> gamesForPerson({
    required String entryKey,
    required List<GameSession> games,
    required List<PersonProfile> profiles,
  }) {
    final aliasToProfile = _aliasIndex(profiles);
    final results = <PersonGameResult>[];

    for (final game in games) {
      if (!isComplete(game)) continue;
      for (final player in game.players) {
        if (!game.hasCashedOut(player.id)) continue;
        final profile = aliasToProfile[PersonProfile.normalize(player.name)];
        final key = profile?.id ?? PersonProfile.normalize(player.name);
        if (key != entryKey) continue;
        results.add(PersonGameResult(
          sessionId: game.id,
          playedAt: game.createdAt,
          net: game.netResultFor(player.id),
          currencyCode: game.currencyCode,
          nameUsed: player.name,
        ));
      }
    }

    results.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return results;
  }

  /// All distinct player names ever used (history + profile aliases), for
  /// autocomplete suggestions when seating players.
  static List<String> knownNames({
    required List<GameSession> games,
    required List<PersonProfile> profiles,
  }) {
    final byLower = <String, String>{}; // normalized -> display form
    for (final game in games) {
      for (final player in game.players) {
        byLower.putIfAbsent(PersonProfile.normalize(player.name), () => player.name);
      }
    }
    for (final profile in profiles) {
      byLower[PersonProfile.normalize(profile.displayName)] = profile.displayName;
    }
    final names = byLower.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  static Map<String, PersonProfile> _aliasIndex(List<PersonProfile> profiles) {
    final map = <String, PersonProfile>{};
    for (final profile in profiles) {
      for (final alias in profile.aliases) {
        map[alias] = profile;
      }
    }
    return map;
  }
}

class _Agg {
  _Agg({
    required this.key,
    required this.displayName,
    required this.colorHex,
    required this.photoPath,
    required this.currencyCode,
  });

  final String key;
  final String displayName;
  final String colorHex;
  final String? photoPath;
  final String currencyCode;

  int gamesPlayed = 0;
  int wins = 0;
  double netTotal = 0;
  double biggestWin = 0;
  double totalBuyIn = 0;
}
