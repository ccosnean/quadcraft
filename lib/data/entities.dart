import 'package:objectbox/objectbox.dart';

/// Best result recorded for one level.
@Entity()
class LevelRecord {
  LevelRecord({
    this.id = 0,
    required this.levelNumber,
    required this.bestMoves,
    this.clears = 1,
  });

  factory LevelRecord.fromJson(Map<String, dynamic> json) => LevelRecord(
    levelNumber: json['levelNumber'] as int,
    bestMoves: json['bestMoves'] as int,
    clears: json['clears'] as int? ?? 1,
  );

  @Id()
  int id;

  @Unique()
  int levelNumber;
  int bestMoves;

  /// How many times the level has been completed.
  int clears;

  Map<String, Object> toJson() => {
    'levelNumber': levelNumber,
    'bestMoves': bestMoves,
    'clears': clears,
  };

  @override
  String toString() =>
      'LevelRecord($levelNumber, best: $bestMoves, clears: $clears)';
}

/// Singleton row for sound, music, language, confetti and target preview.
@Entity()
class AppPrefs {
  AppPrefs({
    this.id = 0,
    this.muted = false,
    this.musicOff = false,
    this.keys = 0,
    this.keysDay = 0,
    this.earnedKeys = 0,
    this.confetti = 'full',
    this.language = 'en',
    this.targetPreview = 'auto',
    this.tutorialSkipped = false,
    this.devUnlockAll = false,
  });

  @Id()
  int id;

  bool muted;

  /// Whether the background bed is switched off. Kept apart from [muted]
  /// so the two can disagree: wanting the clicks and thuds without the
  /// music is a normal taste.
  ///
  /// Stored negated so that a row written before music existed — which
  /// reads back a missing bool as false — comes out with music ON, the
  /// same as a fresh install. Callers use `musicEnabled` and never see it.
  bool musicOff;

  /// Unspent keys for [keysDay]. Both read back as zero on a row written
  /// before keys existed, and a day of zero is never today, so an upgrading
  /// save simply gets its first refill on the next read.
  int keys;

  /// The day those keys were granted, as `yyyymmdd` in local time.
  int keysDay;

  /// Keys won by playing, which do not expire.
  ///
  /// Kept apart from [keys] because the two have opposite rules: the daily
  /// grant is deliberately use-it-or-lose-it, while a key earned over ten
  /// levels was worked for and has to still be there tomorrow. One counter
  /// could not be both.
  int earnedKeys;

  String confetti;
  String language;
  String targetPreview;

  /// The player asked to get on with it. The lessons stay where they are —
  /// this only says they are no longer the thing standing in front of the
  /// ladder.
  bool tutorialSkipped;

  /// Debug-build override: every campaign level and the dive are unlocked
  /// regardless of what has actually been cleared. Never surfaced outside
  /// `kDebugMode`, so it cannot reach a release build's settings screen.
  bool devUnlockAll;

  @override
  String toString() =>
      'AppPrefs(muted: $muted, musicOff: $musicOff, '
      'keys: $keys/$keysDay +$earnedKeys, '
      'confetti: $confetti, '
      'lang: $language, '
      'preview: $targetPreview, skipped: $tutorialSkipped, '
      'devUnlockAll: $devUnlockAll)';
}

/// The dive in progress. One row: a run is a seed plus how far down it got.
///
/// Nothing about the generated levels themselves is stored — the seed rebuilds
/// them — so a run costs a handful of integers no matter how deep it goes.
@Entity()
class DiveRun {
  DiveRun({
    this.id = 0,
    required this.seed,
    this.homeSeed = 0,
    this.depth = 1,
    this.deepest = 0,
    this.clears = 0,
    this.runs = 1,
    this.keyUnlocked = const [],
  });

  @Id()
  int id;

  /// Rebuilds every level in this run. Short enough to read out loud.
  int seed;

  /// The seed this install was born with, drawn once and never redrawn.
  ///
  /// Kept separately from [seed] so that taking a friend's seed is always
  /// reversible: their ladder is a place you can visit, and this is the way
  /// back to your own. Zero on rows written before seeds became per-install,
  /// which the store reads as the seed everyone used to share.
  int homeSeed;

  /// The depth waiting to be played.
  int depth;

  /// Deepest depth cleared in this run.
  int deepest;

  /// Depths cleared in this run.
  int clears;

  /// How many runs have been started on this device, this one included.
  int runs;

  /// Depths opened with a key rather than reached.
  ///
  /// Stored with the run rather than with the keys themselves, because a depth
  /// is a different puzzle under a different seed — re-seeding has to forget
  /// these for the same reason it forgets the records.
  List<int> keyUnlocked;

  @override
  String toString() =>
      'DiveRun(seed: $seed, home: $homeSeed, depth: $depth, '
      'deepest: $deepest)';
}

/// Best result for one depth of the current run. Cleared when a new run
/// starts, because the same depth is a different puzzle under a new seed.
@Entity()
class DiveRecord {
  DiveRecord({
    this.id = 0,
    required this.depth,
    required this.bestMoves,
    this.clears = 1,
  });

  @Id()
  int id;

  @Unique()
  int depth;
  int bestMoves;
  int clears;

  @override
  String toString() => 'DiveRecord($depth, best: $bestMoves)';
}

/// A target the player has finished at least once, anywhere, ever.
///
/// This is the part of the dive that survives a new run: the collection is the
/// long game, and finding a shape nobody has built before is the reason to
/// keep going down.
@Entity()
class Discovery {
  Discovery({
    this.id = 0,
    required this.shapeId,
    required this.depth,
    required this.foundAt,
  });

  @Id()
  int id;

  /// Canonical [Shape] id of the target.
  @Unique()
  String shapeId;

  /// Depth it was first built at.
  int depth;

  /// Epoch milliseconds, so the collection can be shown newest first.
  int foundAt;

  @override
  String toString() => 'Discovery($shapeId at depth $depth)';
}
