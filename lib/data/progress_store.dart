import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Best result recorded for one level.
class LevelRecord {
  LevelRecord({
    required this.levelNumber,
    required this.bestMoves,
    this.clears = 1,
  });

  factory LevelRecord.fromJson(Map<String, dynamic> json) => LevelRecord(
        levelNumber: json['levelNumber'] as int,
        bestMoves: json['bestMoves'] as int,
        clears: json['clears'] as int? ?? 1,
      );

  int levelNumber;
  int bestMoves;

  /// How many times the level has been completed.
  int clears;

  Map<String, Object> toJson() => {
        'levelNumber': levelNumber,
        'bestMoves': bestMoves,
        'clears': clears,
      };
}

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

/// Storage contract used by the app. Keeping it abstract lets the game fall
/// back to memory if the file cannot be opened, and lets tests run without
/// touching disk.
abstract interface class ProgressRepository {
  LevelRecord? recordFor(int levelNumber);

  List<LevelRecord> allRecords();

  int highestUnlocked(int levelCount);

  ClearResult recordClear({
    required int levelNumber,
    required int moves,
  });

  bool get muted;

  set muted(bool value);

  void resetAll();
}

/// Local, offline progress stored as a single JSON file.
class ProgressStore implements ProgressRepository {
  ProgressStore(this._file) {
    _load();
  }

  /// Opens the on-device save file, falling back to an in-memory store so a
  /// storage failure costs the player their history but never the game.
  static Future<ProgressRepository> open() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return ProgressStore(File(p.join(dir.path, 'quadcraft-progress.json')));
    } catch (error, stack) {
      debugPrint('quadcraft: falling back to in-memory progress ($error)');
      debugPrintStack(stackTrace: stack, maxFrames: 6);
      return MemoryProgressStore();
    }
  }

  final File _file;
  final Map<int, LevelRecord> _records = {};
  bool _muted = false;

  @override
  LevelRecord? recordFor(int levelNumber) => _records[levelNumber];

  @override
  List<LevelRecord> allRecords() => _records.values.toList();

  @override
  int highestUnlocked(int levelCount) => firstUnsolved(levelCount, recordFor);

  @override
  ClearResult recordClear({
    required int levelNumber,
    required int moves,
  }) {
    final merged = mergeClear(
      existing: recordFor(levelNumber),
      levelNumber: levelNumber,
      moves: moves,
    );
    _records[levelNumber] = merged.record;
    _save();
    return merged.result;
  }

  @override
  bool get muted => _muted;

  @override
  set muted(bool value) {
    _muted = value;
    _save();
  }

  @override
  void resetAll() {
    _records.clear();
    _muted = false;
    _save();
  }

  void _load() {
    if (!_file.existsSync()) return;
    try {
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return;
      _muted = decoded['muted'] == true;
      final levels = decoded['levels'];
      if (levels is! List) return;
      for (final entry in levels) {
        if (entry is! Map<String, dynamic>) continue;
        final record = LevelRecord.fromJson(entry);
        _records[record.levelNumber] = record;
      }
    } catch (error, stack) {
      debugPrint('quadcraft: ignoring unreadable save file ($error)');
      debugPrintStack(stackTrace: stack, maxFrames: 4);
    }
  }

  void _save() {
    final payload = jsonEncode({
      'muted': _muted,
      'levels': [for (final record in _records.values) record.toJson()],
    });
    final sibling = File('${_file.path}.tmp');
    sibling.writeAsStringSync(payload);
    sibling.renameSync(_file.path);
  }
}

/// Volatile stand-in used by tests and as the fallback when the save file is
/// unavailable.
class MemoryProgressStore implements ProgressRepository {
  final Map<int, LevelRecord> _records = {};

  @override
  bool muted = false;

  @override
  LevelRecord? recordFor(int levelNumber) => _records[levelNumber];

  @override
  List<LevelRecord> allRecords() => _records.values.toList();

  @override
  int highestUnlocked(int levelCount) => firstUnsolved(levelCount, recordFor);

  @override
  ClearResult recordClear({
    required int levelNumber,
    required int moves,
  }) {
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
