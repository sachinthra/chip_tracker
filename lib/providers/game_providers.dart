import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/avatar_colors.dart';
import '../services/backup/backup_service.dart';
import '../services/local/local_storage_service.dart';
import '../services/settlement/settlement_engine.dart';
import '../services/splitwise/splitwise_service.dart';
import '../models/game_session.dart';
import '../models/ledger_entry.dart';
import '../models/player.dart';
import '../models/settlement_transaction.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError(
    'Override localStorageServiceProvider in main.dart after calling init().',
  );
});

final splitwiseServiceProvider = Provider<SplitwiseService>((ref) {
  return SplitwiseService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(localStorageServiceProvider));
});

/// Holds the currently active game (null when no game is in progress) and
/// exposes the drag-and-drop actions the Game Table screen triggers.
///
/// Every mutation is immediately persisted to [LocalStorageService] so the
/// game survives an app restart or force-quit. It's only removed from
/// storage via [clearGame], which callers should only invoke after an
/// explicit user choice (delete, or successfully saved to history).
class ActiveGameNotifier extends Notifier<GameSession?> {
  @override
  GameSession? build() => ref.read(localStorageServiceProvider).getActiveGame();

  void _commit(GameSession session) {
    state = session;
    ref.read(localStorageServiceProvider).saveActiveGame(session);
  }

  void startGame(GameSession session) => _commit(session);

  void recordBuyIn(String playerId) {
    final session = state;
    if (session == null) return;
    _commit(session.copyWith(
      ledger: [
        ...session.ledger,
        LedgerEntry.buyIn(playerId: playerId, chips: session.chipsPerBuyIn),
      ],
    ));
  }

  void recordLoan({required String lenderId, required String borrowerId}) {
    final session = state;
    if (session == null) return;
    _commit(session.copyWith(
      ledger: [
        ...session.ledger,
        LedgerEntry.loan(
          lenderId: lenderId,
          borrowerId: borrowerId,
          chips: session.chipsPerBuyIn,
        ),
      ],
    ));
  }

  void recordCashOut(String playerId, int chips) {
    final session = state;
    if (session == null) return;
    final withoutPriorCashOut = session.ledger
        .where((e) => !(e.type == LedgerEntryType.cashOut && e.toPlayerId == playerId))
        .toList();
    _commit(session.copyWith(
      ledger: [
        ...withoutPriorCashOut,
        LedgerEntry.cashOut(playerId: playerId, chips: chips),
      ],
    ));
  }

  /// Removes any recorded cash-out for [playerId] (they haven't left yet).
  void clearCashOut(String playerId) {
    final session = state;
    if (session == null) return;
    if (!session.hasCashedOut(playerId)) return;
    _commit(session.copyWith(
      ledger: session.ledger
          .where((e) => !(e.type == LedgerEntryType.cashOut && e.toPlayerId == playerId))
          .toList(),
    ));
  }

  /// Seats a new player mid-game (a late joiner). Gives them [buyInCount]
  /// initial buy-ins. Returns the created player's id, or null if a player
  /// with the same name already exists.
  String? addPlayer(String name, {int buyInCount = 1}) {
    final session = state;
    if (session == null) return null;
    if (session.hasPlayerNamed(name)) return null;
    final player = Player(
      name: name.trim(),
      avatarColorHex: AvatarColors.next(
        session.players.map((p) => p.avatarColorHex),
      ),
    );
    final buyIns = List.generate(
      buyInCount,
      (_) => LedgerEntry.buyIn(playerId: player.id, chips: session.chipsPerBuyIn),
    );
    _commit(session.copyWith(
      players: [...session.players, player],
      ledger: [...session.ledger, ...buyIns],
    ));
    return player.id;
  }

  /// Removes [playerId] and every ledger entry that references them (their
  /// buy-ins, cash-out, and any loans they were party to).
  void removePlayer(String playerId) {
    final session = state;
    if (session == null) return;
    _commit(session.copyWith(
      players: session.players.where((p) => p.id != playerId).toList(),
      ledger: session.ledger
          .where((e) => e.toPlayerId != playerId && e.fromPlayerId != playerId)
          .toList(),
    ));
  }

  /// Replaces [playerId]'s buy-in entries so they have exactly [count] of them.
  void setBuyInCount(String playerId, int count) {
    final session = state;
    if (session == null || count < 0) return;
    final otherEntries = session.ledger
        .where((e) => !(e.type == LedgerEntryType.buyIn && e.toPlayerId == playerId))
        .toList();
    final buyIns = List.generate(
      count,
      (_) => LedgerEntry.buyIn(playerId: playerId, chips: session.chipsPerBuyIn),
    );
    _commit(session.copyWith(ledger: [...otherEntries, ...buyIns]));
  }

  /// Moves one buy-in (a single 500 stack) from [fromId] to [toId]: the giver's
  /// buy-in count drops by one, the receiver's rises by one. Returns false if
  /// the giver has no buy-in left or fewer than one stack of chips to hand over.
  bool moveBuyIn(String fromId, String toId) {
    final session = state;
    if (session == null) return false;
    final fromCount =
        session.totalBuyInChips(fromId) ~/ session.chipsPerBuyIn;
    if (fromCount < 1) return false;
    if (session.currentChipStack(fromId) < session.chipsPerBuyIn) return false;

    var removedOne = false;
    final ledger = <LedgerEntry>[];
    for (final entry in session.ledger) {
      if (!removedOne &&
          entry.type == LedgerEntryType.buyIn &&
          entry.toPlayerId == fromId) {
        removedOne = true; // drop exactly one of the giver's buy-ins
        continue;
      }
      ledger.add(entry);
    }
    ledger.add(LedgerEntry.buyIn(playerId: toId, chips: session.chipsPerBuyIn));
    _commit(session.copyWith(ledger: ledger));
    return true;
  }

  void markSettled() {
    final session = state;
    if (session == null) return;
    _commit(session.copyWith(status: GameSessionStatus.settled));
  }

  /// Saves the current game into the History Vault (idempotent — keyed by id,
  /// so re-saving just updates the existing entry).
  void saveToHistory() {
    final session = state;
    if (session == null) return;
    ref.read(localStorageServiceProvider).saveSession(session);
  }

  /// Discards the in-progress game entirely (explicit delete, or after it's
  /// been saved to history) — the only way the active game slot is cleared.
  void clearGame() {
    state = null;
    ref.read(localStorageServiceProvider).clearActiveGame();
  }

  List<SettlementTransaction> computeSettlement() {
    final session = state;
    if (session == null) return [];
    return SettlementEngine.settle(session);
  }
}

final activeGameProvider =
    NotifierProvider<ActiveGameNotifier, GameSession?>(ActiveGameNotifier.new);
