import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio/sfx.dart';
import 'core/level/levels.dart';
import 'data/progress_store.dart';
import 'l10n/l10n.dart';

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
      records: {
        for (final record in store.allRecords()) record.levelNumber: record,
      },
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
    ref.invalidate(mutedProvider);
    ref.invalidate(confettiProvider);
    ref.invalidate(targetPreviewProvider);
    ref.invalidate(languageProvider);
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, ProgressSnapshot>(
  ProgressNotifier.new,
);

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

class ConfettiNotifier extends Notifier<ConfettiAmount> {
  @override
  ConfettiAmount build() => ref.read(progressStoreProvider).confetti;

  void set(ConfettiAmount value) {
    ref.read(progressStoreProvider).confetti = value;
    state = value;
  }
}

final confettiProvider = NotifierProvider<ConfettiNotifier, ConfettiAmount>(
  ConfettiNotifier.new,
);

class TargetPreviewNotifier extends Notifier<TargetPreviewMode> {
  @override
  TargetPreviewMode build() => ref.read(progressStoreProvider).targetPreview;

  void set(TargetPreviewMode value) {
    ref.read(progressStoreProvider).targetPreview = value;
    state = value;
  }
}

final targetPreviewProvider =
    NotifierProvider<TargetPreviewNotifier, TargetPreviewMode>(
      TargetPreviewNotifier.new,
    );

class LanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() =>
      AppLanguage.fromCode(ref.read(progressStoreProvider).languageCode);

  void set(AppLanguage language) {
    ref.read(progressStoreProvider).languageCode = language.code;
    state = language;
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(
  LanguageNotifier.new,
);

final l10nProvider = Provider<L10n>((ref) => L10n(ref.watch(languageProvider)));
