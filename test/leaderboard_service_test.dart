import 'package:flutter_test/flutter_test.dart';
import 'package:track_app/models/game_session.dart';
import 'package:track_app/models/ledger_entry.dart';
import 'package:track_app/models/person_profile.dart';
import 'package:track_app/models/player.dart';
import 'package:track_app/services/leaderboard/leaderboard_service.dart';

void main() {
  // A finished 2-player game where [winner] beats [loser] by one 500 stack.
  GameSession game(String winner, String loser, {DateTime? at}) {
    final w = Player(name: winner);
    final l = Player(name: loser);
    return GameSession(
      createdAt: at,
      players: [w, l],
      ledger: [
        LedgerEntry.buyIn(playerId: w.id, chips: 500),
        LedgerEntry.buyIn(playerId: l.id, chips: 500),
        LedgerEntry.cashOut(playerId: w.id, chips: 1000),
        LedgerEntry.cashOut(playerId: l.id, chips: 0),
      ],
    );
  }

  group('LeaderboardService', () {
    test('aggregates net, games, wins across games', () {
      final games = [
        game('Alice', 'Bob', at: DateTime(2026, 1, 1)),
        game('Alice', 'Bob', at: DateTime(2026, 1, 2)),
      ];

      final board = LeaderboardService.buildLeaderboard(games: games, profiles: []);

      expect(board.first.displayName, 'Alice');
      expect(board.first.gamesPlayed, 2);
      expect(board.first.wins, 2);
      expect(board.first.netTotal, closeTo(250.0, 0.001)); // +125 x2
      final bob = board.firstWhere((e) => e.displayName == 'Bob');
      expect(bob.netTotal, closeTo(-250.0, 0.001));
    });

    test('a profile merges two typed names into one person', () {
      final games = [
        game('sachin', 'Bob', at: DateTime(2026, 1, 1)),
        game('sachinthra', 'Bob', at: DateTime(2026, 1, 2)),
      ];
      final profile = PersonProfile(
        displayName: 'Sachin',
        aliases: ['sachin', 'sachinthra'],
      );

      final board =
          LeaderboardService.buildLeaderboard(games: games, profiles: [profile]);

      final sachin = board.firstWhere((e) => e.displayName == 'Sachin');
      expect(sachin.gamesPlayed, 2);
      expect(sachin.netTotal, closeTo(250.0, 0.001));
      // No separate "sachinthra" row.
      expect(board.where((e) => e.displayName.toLowerCase().contains('thra')), isEmpty);
    });

    test('gamesForPerson returns both alias games newest-first', () {
      final games = [
        game('sachin', 'Bob', at: DateTime(2026, 1, 1)),
        game('sachinthra', 'Bob', at: DateTime(2026, 1, 5)),
      ];
      final profile = PersonProfile(
        displayName: 'Sachin',
        aliases: ['sachin', 'sachinthra'],
      );

      final results = LeaderboardService.gamesForPerson(
        entryKey: profile.id,
        games: games,
        profiles: [profile],
      );

      expect(results, hasLength(2));
      expect(results.first.playedAt.isAfter(results.last.playedAt), isTrue);
      expect(results.first.nameUsed, 'sachinthra');
    });

    test('unfinished games (no cash-out) are excluded', () {
      final a = Player(name: 'Alice');
      final b = Player(name: 'Bob');
      final unfinished = GameSession(
        players: [a, b],
        ledger: [
          LedgerEntry.buyIn(playerId: a.id, chips: 500),
          LedgerEntry.buyIn(playerId: b.id, chips: 500),
        ],
      );

      final board =
          LeaderboardService.buildLeaderboard(games: [unfinished], profiles: []);
      expect(board, isEmpty);
    });

    test('knownNames dedupes case-insensitively', () {
      final games = [game('Alice', 'Bob'), game('alice', 'Carl')];
      final names = LeaderboardService.knownNames(games: games, profiles: []);
      final lower = names.map((n) => n.toLowerCase()).toList();
      expect(lower.where((n) => n == 'alice').length, 1);
      expect(lower, containsAll(['alice', 'bob', 'carl']));
    });
  });
}
