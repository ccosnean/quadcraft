import 'package:flutter/foundation.dart';

import '../shape/shape.dart';

/// A single player action.
@immutable
sealed class GameMove {
  const GameMove();

  /// Short label used by the hint sheet.
  String get label;
}

class RotateMove extends GameMove {
  const RotateMove();

  @override
  String get label => 'Rotate';
}

class CutMove extends GameMove {
  const CutMove();

  @override
  String get label => 'Cut';
}

/// Drops the tray blueprint identified by [shapeId] onto the board.
class StackMove extends GameMove {
  const StackMove(this.shapeId);

  final String shapeId;

  @override
  String get label => 'Place';
}

class PaintMove extends GameMove {
  const PaintMove(this.color);

  final QuadColor color;

  @override
  String get label => 'Paint';
}

/// One hand-authored puzzle.
///
/// [solution] is the reference line the level was designed around: it defines
/// [parMoves], drives the in-game hint, and is replayed by the level tests so a
/// broken puzzle can never ship.
@immutable
class Level {
  const Level({
    required this.number,
    required this.name,
    required this.brief,
    required this.goal,
    required this.solution,
    this.start = Shape.empty,
    this.tray = const <Shape>[],
    this.colors = const <QuadColor>[],
    this.canRotate = false,
    this.canCut = false,
  });

  final int number;
  final String name;

  /// One line shown under the level title; teaches the new idea.
  final String brief;

  final Shape goal;
  final Shape start;

  /// Blueprints the player starts with. Blueprints are never consumed.
  final List<Shape> tray;

  final List<QuadColor> colors;
  final bool canRotate;
  final bool canCut;
  final List<GameMove> solution;

  int get parMoves => solution.length;

  String get id => 'level-$number';
}
