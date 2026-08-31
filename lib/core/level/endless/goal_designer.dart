import '../../shape/shape.dart';
import '../level.dart';
import 'designers/goal_designer_v1.dart';
import 'endless_tuning.dart';
import 'seed_random.dart';

/// A proposed puzzle, before anyone has checked it can be built.
class LevelDraft {
  const LevelDraft({
    required this.start,
    required this.goal,
    required this.theme,
  });

  final Shape start;
  final Shape goal;
  final LevelTheme theme;
}

/// One way of drawing dive targets.
///
/// This is versioned because the algorithm is part of what a seed *means*. A
/// seed is a promise that the same ladder comes back — but only if the same
/// designer draws it. Editing the algorithm in place silently rewrites every
/// stored depth record into a score against a puzzle that no longer exists, so
/// a new approach should arrive as a new version standing beside the old one
/// rather than as an edit to it.
abstract interface class GoalDesigner {
  /// Stable identifier. Stored alongside a run, a run can always be rebuilt.
  String get id;

  /// Draws one target. Knows nothing about whether it can be built — that is
  /// the planner's job, and a draft it refuses is simply re-rolled.
  LevelDraft draft(SeedRandom rng, EndlessTuning tuning);
}

/// Every designer this build can draw with.
abstract final class GoalDesigners {
  static const GoalDesignerV1 v1 = GoalDesignerV1();

  /// What the dive is drawn with today.
  static const GoalDesigner current = v1;

  static const List<GoalDesigner> all = <GoalDesigner>[v1];

  /// Falls back to [current] for an id this build does not know, so a save
  /// written by a newer build still opens rather than refusing to load.
  static GoalDesigner byId(String id) {
    for (final designer in all) {
      if (designer.id == id) return designer;
    }
    return current;
  }
}
