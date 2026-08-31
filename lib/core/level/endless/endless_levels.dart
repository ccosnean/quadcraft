import 'dart:collection';

import '../../shape/shape.dart';
import '../game_state.dart';
import '../level.dart';
import 'build_planner.dart';
import 'endless_tuning.dart';
import 'goal_designer.dart';
import 'seed_random.dart';

/// Grows the endless dive.
///
/// A depth is a pure function of `(seed, depth)`: the same run seed rebuilds
/// the same puzzles on any device, so a seed is something players can trade.
/// Nothing is stored except the seed and how deep you got.
///
/// Every level is designed and then *checked* before it is handed out — the
/// planner has to produce a construction for it and that construction has to
/// replay to a solved board through the real engine. A draft that fails either
/// check is thrown away and the next one is drawn, so an unsolvable target can
/// never reach a player.
abstract final class EndlessLevels {
  /// Drafts drawn before the designer settles for the closest near-miss.
  static const int _attempts = 48;

  /// Levels held in memory. The list screen can show a whole revealed chunk
  /// at once, so this has to comfortably outlast a scroll through one —
  /// otherwise every flick back up regenerates what it just threw away.
  static const int _cacheSize = 256;

  static final LinkedHashMap<String, Level> _cache =
      LinkedHashMap<String, Level>();

  static Level forRef(LevelRef ref) =>
      levelAt(seed: ref.seed, depth: ref.number);

  static Level levelAt({required int seed, required int depth}) {
    final key = '$seed:$depth';
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;

    final level = _design(seed: seed, depth: depth < 1 ? 1 : depth);
    _cache[key] = level;
    if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
    return level;
  }

  /// The level for a depth if it has already been built, without building it.
  ///
  /// Lets the level list ask for what is ready and queue the rest, instead of
  /// running the planner inside a scroll frame.
  static Level? cached({required int seed, required int depth}) {
    final hit = _cache.remove('$seed:${depth < 1 ? 1 : depth}');
    if (hit == null) return null;
    return _cache['$seed:${depth < 1 ? 1 : depth}'] = hit;
  }

  static void clearCache() => _cache.clear();

  /// Depths looked back for a target this run has already shown. A shape
  /// repeating right after itself reads as the dive being stuck rather than
  /// deepening — most noticeable early on, when the unlock ladder still
  /// leaves very little to draw from.
  static const int _repeatWindow = 3;

  static Level _design({required int seed, required int depth}) {
    final tuning = EndlessTuning.forDepth(depth);
    // Close enough to the target to stop looking. Wider than a move or two,
    // because a draft that reads well is worth more than a draft that costs
    // exactly the right number of moves.
    final tolerance = (tuning.parTarget * 0.12).clamp(1.0, 3.0);
    final recentGoals = _recentGoalIds(seed, depth);

    // Best draft that does not repeat a nearby target, and separately the
    // best draft regardless — novelty is only ever a tie-breaker among
    // otherwise-valid drafts, never a reason to fall back to the fallback.
    Level? best;
    var bestScore = double.infinity;
    Level? bestAny;
    var bestAnyScore = double.infinity;

    for (var attempt = 0; attempt < _attempts; attempt++) {
      final rng = SeedRandom(mixSeed([seed, depth, attempt]));
      final draft = GoalDesigners.current.draft(rng, tuning);
      final palette = paletteFor(draft.start, draft.goal);
      final plan = BuildPlanner.plan(
        start: draft.start,
        goal: draft.goal,
        palette: palette,
      );
      if (plan == null) continue;

      final level = _compose(
        seed: seed,
        depth: depth,
        tuning: tuning,
        draft: draft,
        palette: palette,
        plan: plan,
      );
      if (!_holdsUp(level)) continue;

      final score = _score(level, tuning);
      if (score < bestAnyScore) {
        bestAnyScore = score;
        bestAny = level;
      }
      if (recentGoals.contains(level.goal.id)) continue;

      if (score < bestScore) {
        bestScore = score;
        best = level;
      }
      if (score <= tolerance) break;
    }

    return best ??
        bestAny ??
        _fallback(seed: seed, depth: depth, tuning: tuning);
  }

  /// Goal ids from the last few depths of this run, read from cache only —
  /// never generated on demand, so jumping straight to a distant depth (a
  /// share link, a test) costs nothing and never recurses.
  static Set<String> _recentGoalIds(int seed, int depth) => {
    for (var back = 1; back <= _repeatWindow; back++)
      if (depth - back >= 1)
        if (_cache['$seed:${depth - back}'] case final level?) level.goal.id,
  };

  /// Distance from the puzzle this depth wanted. Length is the main term; a
  /// crowded tray is penalised because it costs the player more to read the
  /// level than to solve it.
  static double _score(Level level, EndlessTuning tuning) {
    var score = (level.parMoves - tuning.parTarget).abs();
    final overflow = level.tray.length - tuning.maxTray;
    if (overflow > 0) score += overflow * 5;
    return score;
  }

  /// Replays the reference line through the real engine. A level that does not
  /// finish solved is a bug in the planner, not a puzzle — drop it silently and
  /// draw again rather than shipping something nobody can finish.
  static bool _holdsUp(Level level) {
    if (GameState.initial(level).solved) return false;
    try {
      final finished = GameEngine.replay(level, level.solution);
      return finished.solved && finished.moves == level.solution.length;
    } on StateError {
      return false;
    }
  }

  static Level _compose({
    required int seed,
    required int depth,
    required EndlessTuning tuning,
    required LevelDraft draft,
    required List<QuadColor> palette,
    required BuildPlan plan,
  }) {
    final stratum = tuning.stratum;
    return Level(
      number: depth,
      name: 'Depth $depth',
      section: stratumName(stratum),
      brief: briefFor(draft.theme),
      goal: draft.goal,
      start: draft.start,
      tray: plan.tray,
      colors: palette,
      canRotate: plan.usesRotate,
      canCut: plan.usesCut,
      solution: plan.moves,
      kind: LevelKind.endless,
      seed: seed,
      theme: draft.theme,
      stratum: stratum,
    );
  }

  /// A puzzle that cannot fail to be buildable, for the case where every draft
  /// at a depth was refused. In practice this is unreachable; it exists so the
  /// dive has no way to hand back nothing.
  static Level _fallback({
    required int seed,
    required int depth,
    required EndlessTuning tuning,
  }) {
    final form = tuning.forms.isEmpty ? QuadForm.circle : tuning.forms.first;
    final goal = Shape({
      Corner.tl: Quadrant([LayerPiece(form)]),
    });
    final blueprint = Shape({
      Corner.tl: Quadrant([LayerPiece(form)]),
    });
    return Level(
      number: depth,
      name: 'Depth $depth',
      section: stratumName(tuning.stratum),
      brief: briefFor(LevelTheme.open),
      goal: goal,
      tray: [blueprint],
      solution: [StackMove(blueprint.id)],
      kind: LevelKind.endless,
      seed: seed,
      theme: LevelTheme.open,
      stratum: tuning.stratum,
    );
  }

  /// Colours the level must offer: exactly those the player still has to mix.
  /// Anything already on the plate is deliberately left out, which is what
  /// makes a gift unrepeatable and worth saving.
  static List<QuadColor> paletteFor(Shape start, Shape goal) {
    final needed = <QuadColor>{};
    for (final corner in Corner.values) {
      final onPlate = start[corner].depth;
      for (final piece in goal[corner].layers.skip(onPlate)) {
        if (piece.color != QuadColor.uncolored) needed.add(piece.color);
      }
    }
    return [
      for (final unlock in kColorUnlocks)
        if (needed.contains(unlock.color)) unlock.color,
    ];
  }

  /// English fallback names for the bands of the dive. The UI renders the
  /// player's language from [Level.stratum]; these are what tests and the
  /// share card read.
  static const List<String> stratumNames = [
    'The Shallows',
    'Brass Terrace',
    'The Kiln',
    'Verdigris',
    'The Deep Loom',
    'Starfall',
  ];

  static String stratumName(int stratum) {
    final name = stratumNames[stratum % stratumNames.length];
    final cycle = stratum ~/ stratumNames.length;
    return cycle == 0 ? name : '$name ${cycle + 1}';
  }

  /// English fallback briefs. The UI renders [Level.theme] in the player's
  /// language instead.
  static String briefFor(LevelTheme theme) => switch (theme) {
    LevelTheme.open => 'A bare plate. Everything here starts in the tray.',
    LevelTheme.wash =>
      'One weather for all of it. Build raw, then let the '
          'colour fall.',
    LevelTheme.relic =>
      'What is already here is already right. Save it before you paint.',
    LevelTheme.shell =>
      'The coat is on the plate; the lining is not. Build inward, then slide '
          'the coat under.',
    LevelTheme.nested => 'Deep corners. Dress each one from the inside out.',
    LevelTheme.spectrum =>
      'More than one weather. Every colour wants its own trip.',
  };
}
