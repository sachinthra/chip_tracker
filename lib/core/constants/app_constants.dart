/// Table defaults, tunable per game during setup.
class AppConstants {
  AppConstants._();

  /// Chips added to a player's stack per Bank -> Player drag ("a stack").
  static const int defaultChipsPerBuyIn = 500;

  /// Chips moved per Player -> Player drag (a loan "stack").
  static const int defaultChipsPerLoan = 500;

  /// Default chips-per-currency-unit divisor (500 chips / 4 = ₹125).
  static const double defaultChipToCurrencyDivisor = 4;

  static const String defaultCurrencyCode = 'INR';

  /// Increment steps the Cash-Out slider snaps to.
  static const List<int> cashOutSnapIncrements = [100, 500];

  static const String hiveGameSessionsBoxName = 'game_sessions';

  /// Single-slot box that survives app restarts/force-quits until the game
  /// is explicitly saved to history or deleted.
  static const String hiveActiveGameBoxName = 'active_game';
  static const String activeGameKey = 'current';

  /// General app preferences (theme, etc.).
  static const String hiveSettingsBoxName = 'settings';
  static const String themeModeKey = 'themeMode';

  /// Persistent people (merged identities) for the leaderboard.
  static const String hivePeopleBoxName = 'people';
}
