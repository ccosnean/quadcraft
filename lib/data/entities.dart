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

/// Singleton row for sound, language, confetti and target preview.
@Entity()
class AppPrefs {
  AppPrefs({
    this.id = 0,
    this.muted = false,
    this.confetti = 'full',
    this.language = 'en',
    this.targetPreview = 'auto',
  });

  @Id()
  int id;

  bool muted;
  String confetti;
  String language;
  String targetPreview;

  @override
  String toString() =>
      'AppPrefs(muted: $muted, confetti: $confetti, lang: $language, '
      'preview: $targetPreview)';
}
