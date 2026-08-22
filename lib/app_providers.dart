import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio/sfx.dart';
import 'core/level/levels.dart';
import 'data/progress_store.dart';

/// Overridden in `main()` once local progress is loaded.
final progressStoreProvider = Provider<ProgressRepository>(
  (ref) => throw StateError('progressStoreProvider must be overridden'),
);

/// Overridden in `main()` once the clips are warmed up.
final soundBankProvider = Provider<SoundBank>(
  (ref) => throw StateError('soundBankProvider must be overridden'),
);

/// Read-only view of stored progress, rebuilt whenever a level is cleared.
class ProgressSnapshot {
  const ProgressSnapshot({required this.records, required this.unlocked});

  final Map<int, LevelRecord> records;

  /// Highest level number the player is allowed to open.
  final int unlocked;

  LevelRecord? operator [](int levelNumber) => records[levelNumber];

  bool isCleared(int levelNumber) => records.containsKey(levelNumber);
  bool isUnlocked(int levelNumber) => levelNumber <= unlocked;
  int get clearedCount => records.length;
}

class ProgressNotifier extends Notifier<ProgressSnapshot> {
  @override
  ProgressSnapshot build() => _read();

  ProgressSnapshot _read() {
    final store = ref.read(progressStoreProvider);
    return ProgressSnapshot(
      records: {for (final record in store.allRecords()) record.levelNumber: record},
      unlocked: store.highestUnlocked(kLevels.length),
    );
  }

  ClearResult recordClear({required int levelNumber, required int moves}) {
    final store = ref.read(progressStoreProvider);
    final result = store.recordClear(levelNumber: levelNumber, moves: moves);
    state = _read();
    return result;
  }

  void resetProgress() {
    ref.read(progressStoreProvider).resetAll();
    state = _read();
  }
}

final progressProvider =
    NotifierProvider<ProgressNotifier, ProgressSnapshot>(ProgressNotifier.new);

class MutedNotifier extends Notifier<bool> {
  @override
  bool build() {
    final muted = ref.read(progressStoreProvider).muted;
    ref.read(soundBankProvider).muted = muted;
    return muted;
  }

  void toggle() {
    final next = !state;
    ref.read(progressStoreProvider).muted = next;
    ref.read(soundBankProvider).muted = next;
    state = next;
    if (!next) ref.read(soundBankProvider).play(Sfx.tap);
  }
}

final mutedProvider = NotifierProvider<MutedNotifier, bool>(MutedNotifier.new);
