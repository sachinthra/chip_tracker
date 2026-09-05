# Chip Tracker

A zero-friction Flutter app for tracking poker chip buy-ins and cash-outs, settling up
at the end of a game, and (optionally) pushing the result to Splitwise.

## Features

- **Live game table** — add players mid-game, record buy-ins/cash-outs, and move buy-ins
  between players with drag-and-drop.
- **Settlement engine** — computes the minimum set of transactions to settle a game.
- **Splitwise sync** — push the final settlement to a Splitwise group.
- **History Vault** — every finished game is saved locally and can be re-opened.
- **Backup & restore** — export all history + people to a JSON file and import it back
  (de-duplicated by id, so re-importing or moving to a new install is safe).
- **Leaderboard** — net results across games, with mergeable player identities.
- **Side tools** — a dice roller and a side-pot calculator.
- **Light / dark theme** with a persisted preference.

## Tech stack

- Flutter (Dart SDK `^3.13.2`)
- [Riverpod](https://riverpod.dev) for state management (plain `Notifier`s, no codegen)
- [Hive](https://pub.dev/packages/hive) for offline-first local persistence
- `dio` (Splitwise REST), `flutter_secure_storage` (API token), `share_plus`,
  `file_picker`, `intl`, `uuid`

## Getting started

```bash
flutter pub get
flutter run
```

### Build a release APK

```bash
# Per-ABI APKs (smaller downloads)
flutter build apk --split-per-abi

# Or an App Bundle for the Play Store
flutter build appbundle
```

### Run the tests

```bash
flutter test
```

## Project layout

```
lib/
  models/       # GameSession, Player, LedgerEntry, PersonProfile, ...
  providers/    # Riverpod providers (active game, people, settings)
  screens/      # UI (game table, settlement, history, leaderboard, side games)
  services/     # local storage, settlement, splitwise, backup, side-pot
test/           # unit + widget tests
```

## Backup & restore

In **History Vault → ⋮**:

- **Export backup** writes a `chip_tracker_backup_*.json` and opens the share sheet.
- **Import backup** picks a `.json` and merges it in, skipping anything already present.

Because imports de-duplicate by id, the same backup can be applied repeatedly — useful
when moving to a new device or a fresh install.

