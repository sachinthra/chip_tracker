/// One row of the all-time leaderboard, aggregated across history games.
class LeaderboardEntry {
  /// Stable grouping key: the profile id if linked, else the normalized name.
  final String key;
  final String displayName;
  final String colorHex;
  final String? photoPath;
  final String currencyCode;

  final int gamesPlayed;
  final int wins;
  final double netTotal;
  final double biggestWin;

  const LeaderboardEntry({
    required this.key,
    required this.displayName,
    required this.colorHex,
    this.photoPath,
    required this.currencyCode,
    required this.gamesPlayed,
    required this.wins,
    required this.netTotal,
    required this.biggestWin,
  });
}

/// A single game's result for one person (used in per-person history).
class PersonGameResult {
  final String sessionId;
  final DateTime playedAt;
  final double net;
  final String currencyCode;
  final String nameUsed;

  const PersonGameResult({
    required this.sessionId,
    required this.playedAt,
    required this.net,
    required this.currencyCode,
    required this.nameUsed,
  });
}
