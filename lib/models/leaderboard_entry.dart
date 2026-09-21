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

  /// Total currency bought in across all games (for ROI).
  final double totalBuyIn;

  /// Confidence-adjusted Elo shown to users (raw Elo shrunk toward the 1000
  /// baseline until [provisionalThreshold] games are played).
  final double rating;

  /// Raw Elo before the confidence shrink (for debugging / detail views).
  final double rawElo;

  /// True until the person has played [provisionalThreshold] games.
  final bool isProvisional;

  /// Games required before a rating is considered "settled".
  static const int provisionalThreshold = 5;

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
    required this.totalBuyIn,
    required this.rating,
    required this.rawElo,
    required this.isProvisional,
  });

  double get winRate => gamesPlayed == 0 ? 0 : wins / gamesPlayed;
  double get roi => totalBuyIn <= 0 ? 0 : netTotal / totalBuyIn;
  double get avgPerGame => gamesPlayed == 0 ? 0 : netTotal / gamesPlayed;
}

/// The metric the leaderboard is ordered by. Persisted so the user's last
/// choice becomes the default next launch.
enum LeaderboardSort {
  rating('Rating'),
  netTotal('Net winnings'),
  roi('ROI %'),
  winRate('Win rate'),
  gamesPlayed('Games played'),
  avgPerGame('Avg / game'),
  biggestWin('Biggest win');

  const LeaderboardSort(this.label);
  final String label;

  static LeaderboardSort fromName(String? name) =>
      LeaderboardSort.values.firstWhere(
        (s) => s.name == name,
        orElse: () => LeaderboardSort.rating,
      );

  /// Descending comparator (best first) for this metric, with sensible
  /// tie-breakers so the order is stable.
  int compare(LeaderboardEntry a, LeaderboardEntry b) {
    int byGamesThenRating() {
      final g = b.gamesPlayed.compareTo(a.gamesPlayed);
      if (g != 0) return g;
      return b.rating.compareTo(a.rating);
    }

    switch (this) {
      case LeaderboardSort.rating:
        final c = b.rating.compareTo(a.rating);
        return c != 0 ? c : byGamesThenRating();
      case LeaderboardSort.netTotal:
        final c = b.netTotal.compareTo(a.netTotal);
        return c != 0 ? c : byGamesThenRating();
      case LeaderboardSort.roi:
        final c = b.roi.compareTo(a.roi);
        return c != 0 ? c : byGamesThenRating();
      case LeaderboardSort.winRate:
        final c = b.winRate.compareTo(a.winRate);
        return c != 0 ? c : byGamesThenRating();
      case LeaderboardSort.gamesPlayed:
        final c = b.gamesPlayed.compareTo(a.gamesPlayed);
        return c != 0 ? c : b.rating.compareTo(a.rating);
      case LeaderboardSort.avgPerGame:
        final c = b.avgPerGame.compareTo(a.avgPerGame);
        return c != 0 ? c : byGamesThenRating();
      case LeaderboardSort.biggestWin:
        final c = b.biggestWin.compareTo(a.biggestWin);
        return c != 0 ? c : byGamesThenRating();
    }
  }
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
