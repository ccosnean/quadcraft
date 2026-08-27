import 'package:flutter/foundation.dart';

import '../shape/shape.dart';
import '../shape/shape_ops.dart';
import 'level.dart';

/// Why a move could not be applied. Drives feedback (shake, buzz) in the UI.
enum MoveRejection {
  notAllowed,
  boardEmpty,
  nothingToPaint,
  layerLimit,
  unknownBlueprint,
}

/// Result of feeding a move to the engine.
@immutable
class MoveOutcome {
  const MoveOutcome.applied(this.state, {this.discovered = const <Shape>[]})
    : rejection = null,
      blockedCorners = const <Corner>{};

  const MoveOutcome.rejected(
    this.rejection, {
    this.blockedCorners = const <Corner>{},
  }) : state = null,
       discovered = const <Shape>[];

  final GameState? state;
  final MoveRejection? rejection;

  /// Shapes added to the tray by this move (cut halves).
  final List<Shape> discovered;

  /// Quadrants that refused the drop, for the reject flash.
  final Set<Corner> blockedCorners;

  bool get isApplied => rejection == null;
}

/// Immutable snapshot of a puzzle in progress.
@immutable
class GameState {
  const GameState({
    required this.board,
    required this.tray,
    required this.moves,
    required this.solved,
  });

  factory GameState.initial(Level level) => GameState(
    board: level.start,
    tray: List.unmodifiable(_dedupe(level.tray)),
    moves: 0,
    solved: ShapeOps.shapesEqual(level.start, level.goal),
  );

  final Shape board;

  /// Blueprints available to drag. Reusable, deduped, stable order.
  final List<Shape> tray;

  final int moves;
  final bool solved;

  GameState copyWith({
    Shape? board,
    List<Shape>? tray,
    int? moves,
    bool? solved,
  }) => GameState(
    board: board ?? this.board,
    tray: tray == null ? this.tray : List.unmodifiable(tray),
    moves: moves ?? this.moves,
    solved: solved ?? this.solved,
  );

  static List<Shape> _dedupe(Iterable<Shape> shapes) {
    final seen = <String>{};
    final out = <Shape>[];
    for (final shape in shapes) {
      if (shape.isEmpty) continue;
      if (seen.add(shape.id)) out.add(shape);
    }
    return out;
  }
}

/// The rules engine. Deliberately free of Flutter and of any state of its own so
/// the UI, the hint system and the tests all agree on what a move does.
abstract final class GameEngine {
  static MoveOutcome apply(GameState state, GameMove move, Level level) {
    switch (move) {
      case RotateMove():
        // Turn and cut stay available on every level; early puzzles simply
        // teach them one at a time through goals and briefs.
        if (state.board.isEmpty)
          return const MoveOutcome.rejected(MoveRejection.boardEmpty);
        return _commit(state, level, ShapeOps.rotateClockwise(state.board));

      case CutMove():
        if (state.board.isEmpty)
          return const MoveOutcome.rejected(MoveRejection.boardEmpty);
        final halves = ShapeOps.cutHorizontal(state.board);
        final discovered = <Shape>[
          for (final half in [halves.top, halves.bottom])
            if (half.isNotEmpty && !state.tray.any((t) => t.id == half.id))
              half,
        ];
        return _commit(
          state,
          level,
          Shape.empty,
          tray: [...state.tray, ...discovered],
          discovered: discovered,
        );

      case StackMove(:final shapeId):
        final matches = state.tray.where((s) => s.id == shapeId);
        if (matches.isEmpty) {
          return const MoveOutcome.rejected(MoveRejection.unknownBlueprint);
        }
        final blueprint = matches.first;
        final overflow = ShapeOps.overflowingCorners(state.board, blueprint);
        if (overflow.isNotEmpty) {
          return MoveOutcome.rejected(
            MoveRejection.layerLimit,
            blockedCorners: overflow,
          );
        }
        return _commit(state, level, ShapeOps.stack(state.board, blueprint));

      case PaintMove(:final color):
        if (!level.colors.contains(color)) {
          return const MoveOutcome.rejected(MoveRejection.notAllowed);
        }
        if (state.board.isEmpty)
          return const MoveOutcome.rejected(MoveRejection.boardEmpty);
        if (!ShapeOps.canPaint(state.board, color)) {
          return const MoveOutcome.rejected(MoveRejection.nothingToPaint);
        }
        return _commit(state, level, ShapeOps.paintAll(state.board, color));
    }
  }

  static MoveOutcome _commit(
    GameState state,
    Level level,
    Shape board, {
    List<Shape>? tray,
    List<Shape> discovered = const <Shape>[],
  }) {
    return MoveOutcome.applied(
      state.copyWith(
        board: board,
        tray: tray,
        moves: state.moves + 1,
        solved: ShapeOps.shapesEqual(board, level.goal),
      ),
      discovered: discovered,
    );
  }

  /// Replays a full move list from the level's start. Used by the level tests
  /// and by the hint system.
  static GameState replay(Level level, Iterable<GameMove> moves) {
    var state = GameState.initial(level);
    for (final move in moves) {
      final outcome = apply(state, move, level);
      final next = outcome.state;
      if (next == null) {
        throw StateError(
          'level ${level.number} "${level.name}": ${move.label} rejected '
          '(${outcome.rejection}) at move ${state.moves + 1}, board ${state.board.id}',
        );
      }
      state = next;
    }
    return state;
  }
}
