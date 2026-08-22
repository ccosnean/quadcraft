import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../audio/sfx.dart';
import '../../core/level/game_state.dart';
import '../../core/level/level.dart';
import '../../core/level/levels.dart';
import '../../core/shape/shape.dart';
import '../../core/shape/shape_ops.dart';
import '../../data/progress_store.dart';

/// Transient thing that just happened on the board, consumed by the view to
/// run an animation. Never affects rules.
@immutable
sealed class BoardEffect {
  const BoardEffect();
}

class RotatedEffect extends BoardEffect {
  const RotatedEffect();
}

class CutEffect extends BoardEffect {
  const CutEffect(this.top, this.bottom);

  final Shape top;
  final Shape bottom;
}

class StackedEffect extends BoardEffect {
  const StackedEffect(this.touched);

  final Set<Corner> touched;
}

class PaintedEffect extends BoardEffect {
  const PaintedEffect(this.color);

  final QuadColor color;
}

class RejectedEffect extends BoardEffect {
  const RejectedEffect(this.reason, this.corners);

  final MoveRejection reason;
  final Set<Corner> corners;
}

class SolvedEffect extends BoardEffect {
  const SolvedEffect();
}

class ResetEffect extends BoardEffect {
  const ResetEffect();
}

/// Everything the play screen needs to render one attempt at a level.
@immutable
class PlayState {
  const PlayState({
    required this.level,
    required this.game,
    required this.history,
    required this.effect,
    required this.effectId,
    required this.clear,
    required this.hintsUsed,
  });

  factory PlayState.fresh(Level level) => PlayState(
        level: level,
        game: GameState.initial(level),
        history: const [],
        effect: null,
        effectId: 0,
        clear: null,
        hintsUsed: 0,
      );

  final Level level;
  final GameState game;
  final List<GameState> history;

  final BoardEffect? effect;

  /// Increments with every effect so identical effects still trigger.
  final int effectId;

  /// Non-null once the level has been completed and saved.
  final ClearResult? clear;

  final int hintsUsed;

  bool get solved => game.solved;
  bool get canUndo => history.isNotEmpty && !solved;

  PlayState copyWith({
    GameState? game,
    List<GameState>? history,
    BoardEffect? effect,
    int? effectId,
    ClearResult? clear,
    int? hintsUsed,
  }) =>
      PlayState(
        level: level,
        game: game ?? this.game,
        history: history ?? this.history,
        effect: effect ?? this.effect,
        effectId: effectId ?? this.effectId,
        clear: clear ?? this.clear,
        hintsUsed: hintsUsed ?? this.hintsUsed,
      );
}

class PlayController extends AutoDisposeFamilyNotifier<PlayState, int> {
  @override
  PlayState build(int levelNumber) => PlayState.fresh(levelByNumber(levelNumber));

  SoundBank get _sound => ref.read(soundBankProvider);

  void rotate() => _run(const RotateMove(), const RotatedEffect(), Sfx.rotate);

  void cut() {
    final halves = ShapeOps.cutHorizontal(state.game.board);
    _run(const CutMove(), CutEffect(halves.top, halves.bottom), Sfx.cut);
  }

  void drop(Shape blueprint) {
    final touched = blueprint.filledCorners.toSet();
    _run(StackMove(blueprint.id), StackedEffect(touched), Sfx.drop);
  }

  void paint(QuadColor color) => _run(PaintMove(color), PaintedEffect(color), Sfx.paint);

  void _run(GameMove move, BoardEffect effect, Sfx sound) {
    if (state.solved) return;
    final outcome = GameEngine.apply(state.game, move, state.level);
    final next = outcome.state;

    if (next == null) {
      _sound.play(Sfx.blocked);
      state = state.copyWith(
        effect: RejectedEffect(outcome.rejection!, outcome.blockedCorners),
        effectId: state.effectId + 1,
      );
      return;
    }

    _sound.play(sound);
    state = state.copyWith(
      game: next,
      history: [...state.history, state.game],
      effect: effect,
      effectId: state.effectId + 1,
    );

    if (next.solved) _finish();
  }

  void _finish() {
    final clear = ref.read(progressProvider.notifier).recordClear(
          levelNumber: state.level.number,
          moves: state.game.moves,
        );
    _sound.play(Sfx.win);
    state = state.copyWith(
      clear: clear,
      effect: const SolvedEffect(),
      effectId: state.effectId + 1,
    );
  }

  void undo() {
    if (!state.canUndo) {
      _sound.play(Sfx.blocked);
      return;
    }
    _sound.play(Sfx.tap);
    final history = [...state.history];
    final previous = history.removeLast();
    state = state.copyWith(
      game: previous,
      history: history,
      effect: const ResetEffect(),
      effectId: state.effectId + 1,
    );
  }

  void reset() {
    _sound.play(Sfx.tap);
    state = PlayState.fresh(state.level).copyWith(
      effect: const ResetEffect(),
      effectId: state.effectId + 1,
      hintsUsed: state.hintsUsed,
    );
  }

  /// Reveals the next step of the authored solution, replayed against the
  /// player's current position when it still matches the reference line.
  GameMove? revealHint() {
    final solution = state.level.solution;
    final index = state.game.moves;
    if (index >= solution.length) return null;

    // Only meaningful while the player has followed the reference line; past
    // that we still show the first step from a fresh board as guidance.
    final expected = GameEngine.replay(state.level, solution.take(index));
    final onLine = expected.board.id == state.game.board.id;
    state = state.copyWith(hintsUsed: state.hintsUsed + 1);
    _sound.play(Sfx.tap);
    return onLine ? solution[index] : solution.first;
  }
}

final playControllerProvider =
    NotifierProvider.autoDispose.family<PlayController, PlayState, int>(PlayController.new);
