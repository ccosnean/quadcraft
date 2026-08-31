import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/l10n.dart';
import '../objectbox.g.dart';
import 'entities.dart';

export 'entities.dart';

/// Dive clears that open the whole ladder.
///
/// A hundred puzzles is long past the point where the sequential unlock is
/// teaching anything: whoever has done that many has proved they can, and the
/// ladder should stop deciding what they play next. It is earned once and
/// never lost — the count only goes up.
const int kFreeExplorerClears = 100;

/// Keys granted each day.
///
/// Small on purpose. A key is for the level you are stuck on, not a way to
/// walk down the ladder without playing it — and the point of a daily grant is
/// that tomorrow is a reason to come back.
const int kDailyKeys = 3;

/// Today as `yyyymmdd`, in local time.
///
/// Local rather than UTC because "a day" is the player's day; a refill that
/// lands mid-afternoon for half the world is a bug they would feel.
int dayStamp(DateTime now) => now.year * 10000 + now.month * 100 + now.day;

/// Dive clears that win a key outright.
///
/// Unlike the daily grant these are earned, so they bank: ten levels of work
/// should still be worth something tomorrow morning.
const int kClearsPerKey = 10;

/// What the daily purse should hold, given what it held and when.
///
/// The daily grant does not accumulate. Three a day is a rhythm; thirty saved
/// up over a fortnight is a skeleton key. Keys won by playing are counted
/// separately, in `AppPrefs.earnedKeys`, precisely so this rule cannot eat
/// them.
({int keys, int day}) refilledKeys({
  required int keys,
  required int grantedOn,
  required int today,
}) => grantedOn == today
    ? (keys: keys, day: grantedOn)
    : (keys: kDailyKeys, day: today);

/// Result of finishing a level, used to drive the win sheet.
class ClearResult {
  const ClearResult({
    required this.moves,
    required this.bestMoves,
    required this.isNewBestMoves,
    required this.isFirstClear,
    this.isNewDepth = false,
    this.isNewDiscovery = false,
    this.becameFreeExplorer = false,
    this.earnedKey = false,
  });

  final int moves;
  final int bestMoves;
  final bool isNewBestMoves;
  final bool isFirstClear;

  /// Dive only: this run has never been this deep.
  final bool isNewDepth;

  /// Dive only: this target had never been built before, on any run.
  final bool isNewDiscovery;

  /// Dive only: this was the clear that opened the whole ladder. True on
  /// exactly one clear per install.
  final bool becameFreeExplorer;

  /// Dive only: this clear was a tenth one and won a key.
  final bool earnedKey;
}

/// How many pieces fly when a level is solved.
enum ConfettiAmount {
  full,
  reduced,
  off;

  static ConfettiAmount fromStored({String? code, bool reducedFlag = false}) {
    return switch (code) {
      'reduced' => ConfettiAmount.reduced,
      'off' => ConfettiAmount.off,
      'full' => ConfettiAmount.full,
      _ => reducedFlag ? ConfettiAmount.reduced : ConfettiAmount.full,
    };
  }

  /// Particle count used by the win-burst overlay.
  int get particles => switch (this) {
    ConfettiAmount.full => 72,
    ConfettiAmount.reduced => 18,
    ConfettiAmount.off => 0,
  };
}

/// How the large target preview behaves when a level opens.
enum TargetPreviewMode {
  /// Skip the overlay; the HUD chip is already in place.
  off,

  /// Show the overlay, then fly it into the HUD on its own.
  auto,

  /// Show the overlay until the player taps.
  manual;

  static TargetPreviewMode fromStored(String? code) => switch (code) {
    'off' => TargetPreviewMode.off,
    'manual' => TargetPreviewMode.manual,
    _ => TargetPreviewMode.auto,
  };
}

/// Storage contract used by the app. Keeping it abstract lets the game fall
/// back to memory if the file cannot be opened, and lets tests run without
/// touching disk.
abstract interface class ProgressRepository {
  LevelRecord? recordFor(int levelNumber);

  List<LevelRecord> allRecords();

  int highestUnlocked(int levelCount);

  ClearResult recordClear({required int levelNumber, required int moves});

  /// The dive in progress, created on first read.
  DiveRun diveRun();

  /// Abandons the current dive and starts a fresh one. Discoveries are kept;
  /// per-depth records are not, because the same depth is a different puzzle
  /// under a new seed.
  DiveRun startDive({required int seed});

  DiveRecord? diveRecordFor(int depth);

  List<DiveRecord> allDiveRecords();

  ClearResult recordDiveClear({
    required int depth,
    required int moves,
    required String goalId,
  });

  /// Every target ever finished, newest first.
  List<Discovery> discoveries();

  /// Keys available to spend: today's grant plus everything won and banked.
  int keysToday();

  /// Opens [depth] with a key. False when the purse is empty, so the caller
  /// can say so rather than silently doing nothing.
  bool unlockWithKey(int depth);

  bool get muted;

  set muted(bool value);

  /// Whether the background music plays. Separate from [muted]: turning the
  /// sound off silences everything, but music can be off on its own.
  bool get musicEnabled;

  set musicEnabled(bool value);

  ConfettiAmount get confetti;

  set confetti(ConfettiAmount value);

  String get languageCode;

  set languageCode(String value);

  TargetPreviewMode get targetPreview;

  set targetPreview(TargetPreviewMode value);

  /// Whether the player chose to get past the lessons rather than finish
  /// them. See [AppPrefs.tutorialSkipped].
  bool get tutorialSkipped;

  set tutorialSkipped(bool value);

  /// Debug-build override: treat every campaign level and the dive as
  /// unlocked. See [AppPrefs.devUnlockAll].
  bool get devUnlockAll;

  set devUnlockAll(bool value);

  /// Wipes solved levels and restores default settings.
  void resetAll();
}

/// Local, offline progress stored in ObjectBox.
class ProgressStore implements ProgressRepository {
  ProgressStore(this.store, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now {
    _prefs();
  }

  /// Injectable so a test can cross midnight without waiting for it.
  final DateTime Function() _now;

  /// Opens the on-device database, falling back to an in-memory store so a
  /// storage failure costs the player their history but never the game.
  static Future<ProgressRepository> open() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final store = await openStore(
        directory: p.join(dir.path, 'quadcraft-objectbox'),
      );
      final progress = ProgressStore(store);
      progress._migrateJsonIfNeeded(dir);
      return progress;
    } catch (error, stack) {
      debugPrint('quadcraft: falling back to in-memory progress ($error)');
      debugPrintStack(stackTrace: stack, maxFrames: 6);
      return MemoryProgressStore();
    }
  }

  final Store store;

  Box<LevelRecord> get _levels => store.box<LevelRecord>();
  Box<AppPrefs> get _prefsBox => store.box<AppPrefs>();
  Box<DiveRun> get _dives => store.box<DiveRun>();
  Box<DiveRecord> get _diveRecords => store.box<DiveRecord>();
  Box<Discovery> get _discoveries => store.box<Discovery>();

  @override
  LevelRecord? recordFor(int levelNumber) {
    final query = _levels
        .query(LevelRecord_.levelNumber.equals(levelNumber))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  @override
  List<LevelRecord> allRecords() => _levels.getAll();

  @override
  int highestUnlocked(int levelCount) => firstUnsolved(levelCount, recordFor);

  @override
  ClearResult recordClear({required int levelNumber, required int moves}) {
    final merged = mergeClear(
      existing: recordFor(levelNumber),
      levelNumber: levelNumber,
      moves: moves,
    );
    _levels.put(merged.record);
    return merged.result;
  }

  @override
  DiveRun diveRun() {
    final existing = _dives.getAll();
    if (existing.isNotEmpty) {
      final run = existing.first;
      // Rows written before seeds were drawn per install have no home to go
      // back to. Theirs is the seed the game used to ship with, which is the
      // one they have actually been playing.
      if (run.homeSeed == 0) {
        run.homeSeed = kLegacySharedSeed;
        _dives.put(run);
      }
      return run;
    }
    final seed = freshDiveSeed();
    final created = DiveRun(seed: seed, homeSeed: seed);
    _dives.put(created);
    return created;
  }

  @override
  DiveRun startDive({required int seed}) {
    final previous = diveRun();
    _diveRecords.removeAll();
    final run = previous
      ..seed = seed
      ..depth = 1
      ..deepest = 0
      ..clears = 0
      ..runs = previous.runs + 1;
    _dives.put(run);
    return run;
  }

  @override
  DiveRecord? diveRecordFor(int depth) {
    final query = _diveRecords.query(DiveRecord_.depth.equals(depth)).build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  @override
  List<DiveRecord> allDiveRecords() => _diveRecords.getAll();

  @override
  ClearResult recordDiveClear({
    required int depth,
    required int moves,
    required String goalId,
  }) {
    final merged = mergeDiveClear(
      existing: diveRecordFor(depth),
      depth: depth,
      moves: moves,
    );
    _diveRecords.put(merged.record);

    final run = diveRun();
    final deeper = depth > run.deepest;
    final wasClears = run.clears;
    run
      ..deepest = deeper ? depth : run.deepest
      ..depth = depth + 1 > run.depth ? depth + 1 : run.depth
      ..clears = merged.result.isFirstClear ? run.clears + 1 : run.clears;
    // Crossed on exactly one clear, so the win sheet can say so once.
    final opened =
        wasClears < kFreeExplorerClears && run.clears >= kFreeExplorerClears;
    // Every tenth clear wins a key. Counted off the total rather than a
    // separate tally, so it cannot drift out of step with what was played.
    final won =
        run.clears > wasClears && run.clears % kClearsPerKey == 0;
    _dives.put(run);
    if (won) {
      final prefs = _prefs();
      _prefsBox.put(prefs..earnedKeys = prefs.earnedKeys + 1);
    }

    return ClearResult(
      moves: merged.result.moves,
      bestMoves: merged.result.bestMoves,
      isNewBestMoves: merged.result.isNewBestMoves,
      isFirstClear: merged.result.isFirstClear,
      isNewDepth: deeper,
      isNewDiscovery: _remember(goalId, depth),
      becameFreeExplorer: opened,
      earnedKey: won,
    );
  }

  @override
  List<Discovery> discoveries() =>
      _discoveries.getAll()..sort((a, b) => b.foundAt.compareTo(a.foundAt));

  @override
  int keysToday() {
    final prefs = _refillDaily();
    return prefs.keys + prefs.earnedKeys;
  }

  AppPrefs _refillDaily() {
    final prefs = _prefs();
    final refilled = refilledKeys(
      keys: prefs.keys,
      grantedOn: prefs.keysDay,
      today: dayStamp(_now()),
    );
    if (refilled.day != prefs.keysDay || refilled.keys != prefs.keys) {
      _prefsBox.put(
        prefs
          ..keys = refilled.keys
          ..keysDay = refilled.day,
      );
    }
    return prefs;
  }

  @override
  bool unlockWithKey(int depth) {
    if (keysToday() <= 0) return false;
    final run = diveRun();
    if (run.keyUnlocked.contains(depth)) return true;
    _dives.put(run..keyUnlocked = [...run.keyUnlocked, depth]);
    final prefs = _refillDaily();
    // Today's grant goes first: it expires tonight, and an earned key does
    // not, so spending them the other way round quietly wastes one.
    if (prefs.keys > 0) {
      prefs.keys -= 1;
    } else {
      prefs.earnedKeys -= 1;
    }
    _prefsBox.put(prefs);
    return true;
  }

  bool _remember(String shapeId, int depth) {
    final query = _discoveries
        .query(Discovery_.shapeId.equals(shapeId))
        .build();
    try {
      if (query.findFirst() != null) return false;
    } finally {
      query.close();
    }
    _discoveries.put(
      Discovery(
        shapeId: shapeId,
        depth: depth,
        foundAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return true;
  }

  @override
  bool get muted => _prefs().muted;

  @override
  set muted(bool value) {
    final prefs = _prefs()..muted = value;
    _prefsBox.put(prefs);
  }

  @override
  bool get musicEnabled => !_prefs().musicOff;

  @override
  set musicEnabled(bool value) {
    final prefs = _prefs()..musicOff = !value;
    _prefsBox.put(prefs);
  }

  @override
  ConfettiAmount get confetti =>
      ConfettiAmount.fromStored(code: _prefs().confetti);

  @override
  set confetti(ConfettiAmount value) {
    final prefs = _prefs()..confetti = value.name;
    _prefsBox.put(prefs);
  }

  @override
  String get languageCode => _prefs().language;

  @override
  set languageCode(String value) {
    final prefs = _prefs()..language = value;
    _prefsBox.put(prefs);
  }

  @override
  TargetPreviewMode get targetPreview =>
      TargetPreviewMode.fromStored(_prefs().targetPreview);

  @override
  set targetPreview(TargetPreviewMode value) {
    final prefs = _prefs()..targetPreview = value.name;
    _prefsBox.put(prefs);
  }

  @override
  bool get tutorialSkipped => _prefs().tutorialSkipped;

  @override
  set tutorialSkipped(bool value) {
    final prefs = _prefs()..tutorialSkipped = value;
    _prefsBox.put(prefs);
  }

  @override
  bool get devUnlockAll => _prefs().devUnlockAll;

  @override
  set devUnlockAll(bool value) {
    final prefs = _prefs()..devUnlockAll = value;
    _prefsBox.put(prefs);
  }

  @override
  void resetAll() {
    _levels.removeAll();
    _diveRecords.removeAll();
    _discoveries.removeAll();
    _dives.removeAll();
    final prefs = _prefs()
      ..muted = false
      ..musicOff = false
      ..confetti = ConfettiAmount.full.name
      ..targetPreview = TargetPreviewMode.auto.name
      ..language = AppLanguage.fromPlatform().code
      ..tutorialSkipped = false
      ..devUnlockAll = false;
    _prefsBox.put(prefs);
  }

  AppPrefs _prefs() {
    final existing = _prefsBox.getAll();
    if (existing.isNotEmpty) return existing.first;
    final created = AppPrefs(language: AppLanguage.fromPlatform().code);
    _prefsBox.put(created);
    return created;
  }

  /// One-shot import from the older JSON save file.
  @visibleForTesting
  void importLegacyJson(Directory dir) => _migrateJsonIfNeeded(dir);

  void _migrateJsonIfNeeded(Directory dir) {
    final file = File(p.join(dir.path, 'quadcraft-progress.json'));
    if (!file.existsSync()) return;
    if (_levels.count() > 0) return;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return;
      final prefs = _prefs()
        ..muted = decoded['muted'] == true
        ..musicOff = decoded['music'] == false
        ..confetti = ConfettiAmount.fromStored(
          code: decoded['confetti'] as String?,
          reducedFlag: decoded['reducedConfetti'] == true,
        ).name
        ..language = AppLanguage.fromCode(
          decoded['language'] as String? ?? AppLanguage.fromPlatform().code,
        ).code
        ..targetPreview = TargetPreviewMode.fromStored(
          decoded['targetPreview'] as String?,
        ).name;
      _prefsBox.put(prefs);
      final levels = decoded['levels'];
      if (levels is List) {
        for (final entry in levels) {
          if (entry is! Map<String, dynamic>) continue;
          _levels.put(LevelRecord.fromJson(entry));
        }
      }
      file.deleteSync();
    } catch (error, stack) {
      debugPrint('quadcraft: ignoring unreadable save file ($error)');
      debugPrintStack(stackTrace: stack, maxFrames: 4);
    }
  }
}

/// Volatile stand-in used by tests and as the fallback when the save file is
/// unavailable.
class MemoryProgressStore implements ProgressRepository {
  MemoryProgressStore({DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  /// Injectable so a test can cross midnight without waiting for it.
  final DateTime Function() _now;

  int _keys = 0;
  int _keysDay = 0;
  int _earnedKeys = 0;

  final Map<int, LevelRecord> _records = {};
  final Map<int, DiveRecord> _diveRecords = {};
  final Map<String, Discovery> _discoveries = {};
  DiveRun? _dive;

  @override
  bool muted = false;

  @override
  bool musicEnabled = true;

  @override
  ConfettiAmount confetti = ConfettiAmount.full;

  @override
  String languageCode = AppLanguage.fromPlatform().code;

  @override
  TargetPreviewMode targetPreview = TargetPreviewMode.auto;

  @override
  bool tutorialSkipped = false;

  @override
  bool devUnlockAll = false;

  @override
  LevelRecord? recordFor(int levelNumber) => _records[levelNumber];

  @override
  List<LevelRecord> allRecords() => _records.values.toList();

  @override
  int highestUnlocked(int levelCount) => firstUnsolved(levelCount, recordFor);

  @override
  ClearResult recordClear({required int levelNumber, required int moves}) {
    final merged = mergeClear(
      existing: _records[levelNumber],
      levelNumber: levelNumber,
      moves: moves,
    );
    _records[levelNumber] = merged.record;
    return merged.result;
  }

  @override
  DiveRun diveRun() {
    final existing = _dive;
    if (existing != null) return existing;
    final seed = freshDiveSeed();
    return _dive = DiveRun(seed: seed, homeSeed: seed);
  }

  @override
  DiveRun startDive({required int seed}) {
    final previous = diveRun();
    _diveRecords.clear();
    return _dive = DiveRun(
      seed: seed,
      homeSeed: previous.homeSeed,
      runs: previous.runs + 1,
    );
  }

  @override
  DiveRecord? diveRecordFor(int depth) => _diveRecords[depth];

  @override
  List<DiveRecord> allDiveRecords() => _diveRecords.values.toList();

  @override
  ClearResult recordDiveClear({
    required int depth,
    required int moves,
    required String goalId,
  }) {
    final merged = mergeDiveClear(
      existing: _diveRecords[depth],
      depth: depth,
      moves: moves,
    );
    _diveRecords[depth] = merged.record;

    final run = diveRun();
    final deeper = depth > run.deepest;
    final wasClears = run.clears;
    run
      ..deepest = deeper ? depth : run.deepest
      ..depth = depth + 1 > run.depth ? depth + 1 : run.depth
      ..clears = merged.result.isFirstClear ? run.clears + 1 : run.clears;
    // Crossed on exactly one clear, so the win sheet can say so once.
    final opened =
        wasClears < kFreeExplorerClears && run.clears >= kFreeExplorerClears;
    // Every tenth clear wins a key. Counted off the total rather than a
    // separate tally, so it cannot drift out of step with what was played.
    final won =
        run.clears > wasClears && run.clears % kClearsPerKey == 0;

    if (won) _earnedKeys += 1;

    final isNew = !_discoveries.containsKey(goalId);
    if (isNew) {
      _discoveries[goalId] = Discovery(
        shapeId: goalId,
        depth: depth,
        foundAt: DateTime.now().millisecondsSinceEpoch,
      );
    }

    return ClearResult(
      moves: merged.result.moves,
      bestMoves: merged.result.bestMoves,
      isNewBestMoves: merged.result.isNewBestMoves,
      isFirstClear: merged.result.isFirstClear,
      isNewDepth: deeper,
      isNewDiscovery: isNew,
      becameFreeExplorer: opened,
      earnedKey: won,
    );
  }

  @override
  List<Discovery> discoveries() =>
      _discoveries.values.toList()
        ..sort((a, b) => b.foundAt.compareTo(a.foundAt));

  @override
  int keysToday() {
    final refilled = refilledKeys(
      keys: _keys,
      grantedOn: _keysDay,
      today: dayStamp(_now()),
    );
    _keys = refilled.keys;
    _keysDay = refilled.day;
    return _keys + _earnedKeys;
  }

  @override
  bool unlockWithKey(int depth) {
    if (keysToday() <= 0) return false;
    final run = diveRun();
    if (run.keyUnlocked.contains(depth)) return true;
    run.keyUnlocked = [...run.keyUnlocked, depth];
    // Today's grant first: it expires tonight and an earned key does not.
    if (_keys > 0) {
      _keys -= 1;
    } else {
      _earnedKeys -= 1;
    }
    return true;
  }

  @override
  void resetAll() {
    _records.clear();
    _diveRecords.clear();
    _discoveries.clear();
    _dive = null;
    muted = false;
    musicEnabled = true;
    _keys = 0;
    _keysDay = 0;
    _earnedKeys = 0;
    tutorialSkipped = false;
    devUnlockAll = false;
    confetti = ConfettiAmount.full;
    targetPreview = TargetPreviewMode.auto;
    languageCode = AppLanguage.fromPlatform().code;
  }
}

/// Highest level the player may enter: the first one without a record.
int firstUnsolved(int levelCount, LevelRecord? Function(int) lookup) {
  for (var n = 1; n <= levelCount; n++) {
    if (lookup(n) == null) return n;
  }
  return levelCount;
}

/// Folds a finished run into the stored best, returning the record to persist
/// and the summary to show the player.
({LevelRecord record, ClearResult result}) mergeClear({
  required LevelRecord? existing,
  required int levelNumber,
  required int moves,
}) {
  if (existing == null) {
    return (
      record: LevelRecord(levelNumber: levelNumber, bestMoves: moves),
      result: ClearResult(
        moves: moves,
        bestMoves: moves,
        isNewBestMoves: true,
        isFirstClear: true,
      ),
    );
  }

  final betterMoves = moves < existing.bestMoves;
  existing
    ..bestMoves = betterMoves ? moves : existing.bestMoves
    ..clears += 1;

  return (
    record: existing,
    result: ClearResult(
      moves: moves,
      bestMoves: existing.bestMoves,
      isNewBestMoves: betterMoves,
      isFirstClear: false,
    ),
  );
}

/// The seed every install used to start on, back when there was only one.
///
/// Kept solely so a save file written before seeds were drawn per install
/// still knows which ladder it has been climbing, and can be sent home to it.
/// Nothing new is ever put on this seed.
const int kLegacySharedSeed = 240816;

/// A run seed the player can read out loud and type back in.
///
/// Drawn once per install, which is what makes a seed worth trading: your
/// ladder is yours, and taking somebody else's is a decision rather than the
/// default everyone was already on.
int freshDiveSeed() =>
    100000 + DateTime.now().microsecondsSinceEpoch.abs() % 900000;

/// Folds a finished dive into the stored best for that depth.
({DiveRecord record, ClearResult result}) mergeDiveClear({
  required DiveRecord? existing,
  required int depth,
  required int moves,
}) {
  if (existing == null) {
    return (
      record: DiveRecord(depth: depth, bestMoves: moves),
      result: ClearResult(
        moves: moves,
        bestMoves: moves,
        isNewBestMoves: true,
        isFirstClear: true,
      ),
    );
  }

  final better = moves < existing.bestMoves;
  existing
    ..bestMoves = better ? moves : existing.bestMoves
    ..clears += 1;

  return (
    record: existing,
    result: ClearResult(
      moves: moves,
      bestMoves: existing.bestMoves,
      isNewBestMoves: better,
      isFirstClear: false,
    ),
  );
}
