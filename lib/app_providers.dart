import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio/music.dart';
import 'audio/sfx.dart';
import 'core/level/endless/endless_levels.dart';
import 'core/level/level.dart';
import 'core/level/level_catalog.dart';
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

/// Overridden in `main()` once the loops are warmed up. Unlike the sound bank
/// this has a working default, so a widget can be pumped in a test without
/// standing up audio it does not care about.
final musicBedProvider = Provider<MusicBed>((ref) => MusicBed.silent());

/// Read-only view of stored progress, rebuilt whenever a level is cleared.
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.records,
    required this.unlocked,
    this.tutorialSkipped = false,
    this.devUnlockAll = false,
  });

  final Map<int, LevelRecord> records;

  /// Highest level number the player is allowed to open.
  final int unlocked;

  /// The player waved the lessons through. They stay playable from settings;
  /// they just stop being the gate.
  final bool tutorialSkipped;

  /// Debug-build override from settings: every campaign level and the dive
  /// read as unlocked regardless of [unlocked]. Never true outside
  /// `kDebugMode` — the toggle that sets it is hidden from release builds.
  final bool devUnlockAll;

  LevelRecord? operator [](int levelNumber) => records[levelNumber];

  bool isCleared(int levelNumber) => records.containsKey(levelNumber);
  bool isUnlocked(int levelNumber) => devUnlockAll || levelNumber <= unlocked;
  int get clearedCount => records.length;

  /// The generated ladder opens once the tutorial has taught every verb it
  /// uses. Before that a generated puzzle would be asking questions the player
  /// has not been given the vocabulary for.
  ///
  /// Tested against the last tutorial level rather than [unlocked]: the
  /// tutorial is now the whole authored set, and `highestUnlocked` saturates
  /// at its length, so there is no "past the end" for it to report.
  bool get diveOpen =>
      devUnlockAll || tutorialSkipped || isCleared(kTutorialLevelCount);

  /// Whether the lessons are still ahead of the player — which is the only
  /// time skipping them is on offer.
  bool get canSkipTutorial =>
      !tutorialSkipped && !isCleared(kTutorialLevelCount);
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
      tutorialSkipped: store.tutorialSkipped,
      devUnlockAll: store.devUnlockAll,
    );
  }

  ClearResult recordClear({required int levelNumber, required int moves}) {
    final store = ref.read(progressStoreProvider);
    final result = store.recordClear(levelNumber: levelNumber, moves: moves);
    state = _read();
    return result;
  }

  /// Opens the ladder without finishing the lessons. Nothing is faked as
  /// cleared: the tutorial keeps its own record, and settings can still walk
  /// back into it.
  void skipTutorial() {
    ref.read(progressStoreProvider).tutorialSkipped = true;
    state = _read();
  }

  void resetProgress() {
    ref.read(progressStoreProvider).resetAll();
    EndlessLevels.clearCache();
    state = _read();
    ref.invalidate(diveProvider);
    ref.invalidate(mutedProvider);
    ref.invalidate(musicProvider);
    ref.invalidate(confettiProvider);
    ref.invalidate(targetPreviewProvider);
    ref.invalidate(languageProvider);
    ref.invalidate(devUnlockAllProvider);
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, ProgressSnapshot>(
  ProgressNotifier.new,
);

/// Debug-only: unlock every campaign level and the dive, regardless of actual
/// progress. Read by [ProgressSnapshot]; toggled from the settings screen,
/// which only shows the control in `kDebugMode`.
class DevUnlockNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(progressStoreProvider).devUnlockAll;

  void set(bool value) {
    ref.read(progressStoreProvider).devUnlockAll = value;
    state = value;
    ref.invalidate(progressProvider);
  }
}

final devUnlockAllProvider = NotifierProvider<DevUnlockNotifier, bool>(
  DevUnlockNotifier.new,
);

/// Read-only view of the dive: which run is going, how deep it has been, and
/// everything the player has ever built.
class DiveSnapshot {
  const DiveSnapshot({
    required this.seed,
    required this.homeSeed,
    required this.depth,
    required this.deepest,
    required this.clears,
    required this.runs,
    required this.records,
    required this.discoveries,
    required this.keysToday,
    required this.keyUnlocked,
  });

  /// Rebuilds every level in this run.
  final int seed;

  /// The seed this install was given. What "back to mine" means.
  final int homeSeed;

  /// The depth waiting to be played.
  final int depth;

  final int deepest;
  final int clears;
  final int runs;

  final Map<int, DiveRecord> records;

  /// Every target ever finished, newest first. Survives a new run.
  final List<Discovery> discoveries;

  /// Unspent keys for today.
  final int keysToday;

  /// Depths opened with a key rather than reached.
  final Set<int> keyUnlocked;

  DiveRecord? operator [](int depth) => records[depth];

  bool isCleared(int depth) => records.containsKey(depth);

  bool get isFresh => deepest == 0;

  /// The ladder has been opened for good: every depth is playable, in any
  /// order. Earned by clearing [kFreeExplorerClears] of them the long way.
  bool get freeExplorer => clears >= kFreeExplorerClears;

  /// How many more clears until the ladder opens, or zero once it has.
  int get clearsToFreeExplorer =>
      freeExplorer ? 0 : kFreeExplorerClears - clears;

  /// Whether this run is on the seed the install was given, rather than one
  /// taken from somebody else.
  bool get isHomeSeed => seed == homeSeed;

  LevelRef refFor(int depth) => LevelRef.endless(seed: seed, number: depth);

  /// The next depth to open: where the ladder left off.
  LevelRef get frontier => refFor(depth);

  /// Whether a depth is open to play. The ladder unlocks in order, so
  /// everything up to the frontier is fair game and nothing past it is —
  /// until [freeExplorer], after which the order stops mattering, or unless a
  /// key was spent on this one.
  bool isUnlocked(int depth) =>
      freeExplorer || depth <= this.depth || keyUnlocked.contains(depth);

  /// Whether a key would do anything here: locked, and there is one to spend.
  bool canUnlockWithKey(int depth) => !isUnlocked(depth) && keysToday > 0;
}

class DiveNotifier extends Notifier<DiveSnapshot> {
  @override
  DiveSnapshot build() => _read();

  DiveSnapshot _read() {
    final store = ref.read(progressStoreProvider);
    final run = store.diveRun();
    return DiveSnapshot(
      seed: run.seed,
      homeSeed: run.homeSeed,
      depth: run.depth,
      deepest: run.deepest,
      clears: run.clears,
      runs: run.runs,
      records: {
        for (final record in store.allDiveRecords()) record.depth: record,
      },
      discoveries: store.discoveries(),
      keysToday: store.keysToday(),
      keyUnlocked: run.keyUnlocked.toSet(),
    );
  }

  ClearResult recordClear({
    required int depth,
    required int moves,
    required String goalId,
  }) {
    final result = ref
        .read(progressStoreProvider)
        .recordDiveClear(depth: depth, moves: moves, goalId: goalId);
    state = _read();
    return result;
  }

  /// Re-seeds the ladder. Every generated target is a function of the seed,
  /// so per-depth records are dropped with it — they would be scores against
  /// puzzles that no longer exist. Discoveries are kept: the collection is
  /// meant to outlive any one seed.
  void useSeed(int seed) {
    if (seed == state.seed) return;
    ref.read(progressStoreProvider).startDive(seed: seed);
    EndlessLevels.clearCache();
    state = _read();
  }

  /// Spends a key on [depth]. False when the purse is empty.
  bool unlockWithKey(int depth) {
    final spent = ref.read(progressStoreProvider).unlockWithKey(depth);
    if (spent) state = _read();
    return spent;
  }

  /// Back to the seed this install was given.
  void resetSeed() => useSeed(state.homeSeed);

  /// A fresh, arbitrary seed.
  void rollSeed() => useSeed(freshDiveSeed());
}

final diveProvider = NotifierProvider<DiveNotifier, DiveSnapshot>(
  DiveNotifier.new,
);

class MutedNotifier extends Notifier<bool> {
  @override
  bool build() {
    final muted = ref.read(progressStoreProvider).muted;
    ref.read(soundBankProvider).muted = muted;
    ref.read(musicBedProvider).muted = muted;
    return muted;
  }

  void toggle() {
    final next = !state;
    ref.read(progressStoreProvider).muted = next;
    ref.read(soundBankProvider).muted = next;
    // The bed fades rather than cuts, and picks itself back up where it left
    // off if the switch goes back on.
    ref.read(musicBedProvider).muted = next;
    state = next;
    if (!next) ref.read(soundBankProvider).play(Sfx.tap);
  }
}

final mutedProvider = NotifierProvider<MutedNotifier, bool>(MutedNotifier.new);

/// The music switch, which sits under [mutedProvider]: turning the sound off
/// silences the bed too, but turning music off leaves the effects alone.
class MusicNotifier extends Notifier<bool> {
  @override
  bool build() {
    final enabled = ref.read(progressStoreProvider).musicEnabled;
    ref.read(musicBedProvider).enabled = enabled;
    return enabled;
  }

  void toggle() => set(!state);

  void set(bool value) {
    if (value == state) return;
    ref.read(progressStoreProvider).musicEnabled = value;
    ref.read(musicBedProvider).enabled = value;
    state = value;
  }
}

final musicProvider = NotifierProvider<MusicNotifier, bool>(MusicNotifier.new);

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
