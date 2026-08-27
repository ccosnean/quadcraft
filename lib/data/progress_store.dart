import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/l10n.dart';
import '../objectbox.g.dart';
import 'entities.dart';

export 'entities.dart';

/// Result of finishing a level, used to drive the win sheet.
class ClearResult {
  const ClearResult({
    required this.moves,
    required this.bestMoves,
    required this.isNewBestMoves,
    required this.isFirstClear,
  });

  final int moves;
  final int bestMoves;
  final bool isNewBestMoves;
  final bool isFirstClear;
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

  bool get muted;

  set muted(bool value);

  ConfettiAmount get confetti;

  set confetti(ConfettiAmount value);

  String get languageCode;

  set languageCode(String value);

  TargetPreviewMode get targetPreview;

  set targetPreview(TargetPreviewMode value);

  /// Wipes solved levels and restores default settings.
  void resetAll();
}

/// Local, offline progress stored in ObjectBox.
class ProgressStore implements ProgressRepository {
  ProgressStore(this.store) {
    _prefs();
  }

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
  bool get muted => _prefs().muted;

  @override
  set muted(bool value) {
    final prefs = _prefs()..muted = value;
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
  void resetAll() {
    _levels.removeAll();
    final prefs = _prefs()
      ..muted = false
      ..confetti = ConfettiAmount.full.name
      ..targetPreview = TargetPreviewMode.auto.name
      ..language = AppLanguage.fromPlatform().code;
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
  final Map<int, LevelRecord> _records = {};

  @override
  bool muted = false;

  @override
  ConfettiAmount confetti = ConfettiAmount.full;

  @override
  String languageCode = AppLanguage.fromPlatform().code;

  @override
  TargetPreviewMode targetPreview = TargetPreviewMode.auto;

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
  void resetAll() {
    _records.clear();
    muted = false;
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
