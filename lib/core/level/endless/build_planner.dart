import '../../shape/shape.dart';
import '../level.dart';

/// A tray and the reference line that turns a start plate into a goal.
class BuildPlan {
  const BuildPlan({
    required this.tray,
    required this.moves,
    required this.colors,
  });

  /// Blueprints the level ships with. Everything else the player needs is
  /// discovered by cutting.
  final List<Shape> tray;

  final List<GameMove> moves;

  /// Colours the line actually spends, in the order they are first used.
  final List<QuadColor> colors;

  int get length => moves.length;

  bool get usesRotate => moves.any((m) => m is RotateMove);

  bool get usesCut => moves.any((m) => m is CutMove);
}

/// Turns a `(start, goal)` pair into a line of legal moves.
///
/// This is what makes generated levels trustworthy: rather than inventing a
/// target and hoping a solver can reach it, the designer proposes a target and
/// the planner either produces a concrete construction for it or refuses it.
/// Nothing without a construction is ever handed to a player.
///
/// The construction rests on three facts about the rules:
///
///  * a drop only touches the quadrants its blueprint fills, and slides
///    *under* whatever is already there, so a corner can be built from the
///    inside out and corners never interfere with each other;
///  * a cut banks both halves at their own positions, which is the only way to
///    move a painted piece off the plate before the next coat;
///  * a turn is the only thing that moves pieces sideways, so a blueprint that
///    fills the top-left can reach any corner if the plate is turned first.
///
/// So: bank whatever the plate came with, dye the pieces that need dyeing in
/// the workshop (place raw, paint, cut), then assemble corner group by corner
/// group with a turn between them, and finally drop the banked gift back on
/// top of the lining that was built for it.
abstract final class BuildPlanner {
  /// Returns null when [goal] cannot be reached from [start] by this
  /// construction — the caller re-rolls rather than shipping a broken level.
  static BuildPlan? plan({
    required Shape start,
    required Shape goal,
    required List<QuadColor> palette,
  }) {
    final remainders = <Corner, List<LayerPiece>>{};
    for (final corner in Corner.values) {
      final onPlate = start[corner].layers;
      final wanted = goal[corner].layers;
      // Whatever the plate came with has to be the outer shell of the finished
      // corner: drops go underneath, so anything else could never be reached.
      if (onPlate.length > wanted.length) return null;
      for (var i = 0; i < onPlate.length; i++) {
        if (onPlate[i] != wanted[i]) return null;
      }
      remainders[corner] = wanted.sublist(onPlate.length);
    }
    if (remainders.values.every((layers) => layers.isEmpty)) return null;

    final needed = <QuadColor>{
      for (final layers in remainders.values)
        for (final piece in layers)
          if (piece.color != QuadColor.uncolored) piece.color,
    };
    if (!needed.every(palette.contains)) return null;

    final washColor = _washColor(remainders);
    final plans = <BuildPlan>[
      ?_assemble(start: start, remainders: remainders, wash: null),
      if (washColor != null)
        ?_assemble(start: start, remainders: remainders, wash: washColor),
    ];
    if (plans.isEmpty) return null;
    plans.sort((a, b) => a.length.compareTo(b.length));
    return plans.first;
  }

  /// The single colour every unbuilt layer shares, if there is one. Such a
  /// target can skip the workshop entirely: build the whole thing raw and dye
  /// it in one pass at the end, before the gift goes back on.
  static QuadColor? _washColor(Map<Corner, List<LayerPiece>> remainders) {
    QuadColor? color;
    for (final layers in remainders.values) {
      for (final piece in layers) {
        if (piece.color == QuadColor.uncolored) return null;
        if (color == null) {
          color = piece.color;
        } else if (color != piece.color) {
          return null;
        }
      }
    }
    return color;
  }

  static BuildPlan? _assemble({
    required Shape start,
    required Map<Corner, List<LayerPiece>> remainders,
    required QuadColor? wash,
  }) {
    final batches = _schedule(remainders);
    if (batches.isEmpty) return null;

    final moves = <GameMove>[];
    final trayRaw = <String, Shape>{};
    final banked = <String>{};
    final colors = <QuadColor>[];

    final giftTop = Shape({
      Corner.tl: start[Corner.tl],
      Corner.tr: start[Corner.tr],
    });
    final giftBottom = Shape({
      Corner.bl: start[Corner.bl],
      Corner.br: start[Corner.br],
    });

    if (start.isNotEmpty) {
      // Bank the plate before anything else touches it. This is also what puts
      // the gift halves in the tray for the final drop.
      moves.add(const CutMove());
      for (final half in [giftTop, giftBottom]) {
        if (half.isNotEmpty) banked.add(half.id);
      }
    }

    // Workshop: every colour a run needs, dyed off-board and banked.
    if (wash == null) {
      for (final batch in _byDepth(batches)) {
        for (final run in batch.runs.reversed) {
          if (run.color == QuadColor.uncolored) {
            for (final piece in run.layers) {
              _rememberRaw(trayRaw, batch.carrier, piece.form);
            }
            continue;
          }
          final column = batch.carrier.column(run.layers);
          final outputs = batch.carrier.bankedFrom(column);
          if (outputs.every((shape) => banked.contains(shape.id))) continue;
          for (final piece in run.layers.reversed) {
            final raw = _rememberRaw(trayRaw, batch.carrier, piece.form);
            moves.add(StackMove(raw.id));
          }
          moves.add(PaintMove(run.color));
          if (!colors.contains(run.color)) colors.add(run.color);
          moves.add(const CutMove());
          banked.addAll(outputs.map((shape) => shape.id));
        }
      }
    }

    // Assembly: one corner group per turn of the plate, innermost run first.
    final deepest = batches.keys.reduce((a, b) => a > b ? a : b);
    for (var turn = deepest; turn >= 0; turn--) {
      final batch = batches[turn];
      if (batch != null) {
        for (final run in batch.runs.reversed) {
          if (wash != null || run.color == QuadColor.uncolored) {
            for (final piece in run.layers.reversed) {
              final raw = _rememberRaw(trayRaw, batch.carrier, piece.form);
              moves.add(StackMove(raw.id));
            }
          } else {
            final column = batch.carrier.column(run.layers);
            for (final shape in batch.carrier.bankedFrom(column)) {
              moves.add(StackMove(shape.id));
            }
          }
        }
      }
      if (turn > 0) moves.add(const RotateMove());
    }

    if (wash != null) {
      moves.add(PaintMove(wash));
      if (!colors.contains(wash)) colors.add(wash);
    }

    // The gift goes back last so it lands outermost, wrapping the lining that
    // was just built for it — and safely after the last coat of paint.
    for (final half in [giftTop, giftBottom]) {
      if (half.isNotEmpty) moves.add(StackMove(half.id));
    }

    return BuildPlan(
      tray: trayRaw.values.toList(growable: false),
      moves: moves,
      colors: colors,
    );
  }

  static Shape _rememberRaw(
    Map<String, Shape> trayRaw,
    _Carrier carrier,
    QuadForm form,
  ) {
    final raw = carrier.raw(form);
    return trayRaw.putIfAbsent(raw.id, () => raw);
  }

  /// Batches in the order the plate is filled: most turns owed first.
  static List<_Batch> _byDepth(Map<int, _Batch> batches) {
    final keys = batches.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final key in keys) batches[key]!];
  }

  /// Corners that want the same stack are built together by one blueprint,
  /// keyed by the number of turns still owed to that group. Disjoint groups
  /// can never claim the same turn count, so the key is always free.
  static Map<int, _Batch> _schedule(Map<Corner, List<LayerPiece>> remainders) {
    final groups = <String, List<Corner>>{};
    for (final corner in Corner.values) {
      final layers = remainders[corner]!;
      if (layers.isEmpty) continue;
      groups.putIfAbsent(_stackKey(layers), () => <Corner>[]).add(corner);
    }

    final batches = <int, _Batch>{};
    for (final entry in groups.entries) {
      final corners = entry.value;
      final layers = remainders[corners.first]!;
      final runs = _splitRuns(layers);

      if (corners.length == 4) {
        batches[0] = _Batch(_Carrier.plate, runs);
        continue;
      }
      final pairTurn = corners.length == 2 ? _adjacentPairTurn(corners) : null;
      if (pairTurn != null) {
        batches[pairTurn] = _Batch(_Carrier.pair, runs);
        continue;
      }
      for (final corner in corners) {
        batches[_turnsFromTopLeft(corner)] = _Batch(_Carrier.single, runs);
      }
    }
    return batches;
  }

  static String _stackKey(List<LayerPiece> layers) =>
      layers.map((piece) => piece.code).join('+');

  /// Maximal stretches of one colour, outermost first. A stretch can be dyed
  /// and banked as a single column, which is the main saving over doing one
  /// trip to the workshop per piece.
  static List<_Run> _splitRuns(List<LayerPiece> layers) {
    final runs = <_Run>[];
    for (final piece in layers) {
      if (runs.isNotEmpty && runs.last.color == piece.color) {
        runs.last.layers.add(piece);
      } else {
        runs.add(_Run(piece.color, [piece]));
      }
    }
    return runs;
  }

  /// Clockwise quarter-turns that carry the top-left corner onto [corner].
  static int _turnsFromTopLeft(Corner corner) => switch (corner) {
    Corner.tl => 0,
    Corner.tr => 1,
    Corner.br => 2,
    Corner.bl => 3,
  };

  /// Turns that carry the top row onto [corners], or null when the two corners
  /// sit on a diagonal — no single blueprint can ever fill those together.
  static int? _adjacentPairTurn(List<Corner> corners) {
    final wanted = corners.toSet();
    for (var turn = 0; turn < 4; turn++) {
      final rotated = {_rotate(Corner.tl, turn), _rotate(Corner.tr, turn)};
      if (rotated.length == wanted.length && rotated.containsAll(wanted)) {
        return turn;
      }
    }
    return null;
  }

  static Corner _rotate(Corner corner, int turns) {
    const clockwise = {
      Corner.tl: Corner.tr,
      Corner.tr: Corner.br,
      Corner.br: Corner.bl,
      Corner.bl: Corner.tl,
    };
    var out = corner;
    for (var i = 0; i < turns; i++) {
      out = clockwise[out]!;
    }
    return out;
  }
}

class _Run {
  _Run(this.color, this.layers);

  final QuadColor color;

  /// Outermost first, matching [Quadrant.layers].
  final List<LayerPiece> layers;
}

class _Batch {
  const _Batch(this.carrier, this.runs);

  final _Carrier carrier;

  /// Outermost run first.
  final List<_Run> runs;
}

/// The blueprint footprint a batch builds through.
///
/// A cut always splits along the horizontal, which is why the whole plate is
/// the only footprint that comes back from the workshop in two pieces.
enum _Carrier {
  single([Corner.tl]),
  pair([Corner.tl, Corner.tr]),
  plate(Corner.values);

  const _Carrier(this.positions);

  final List<Corner> positions;

  Shape raw(QuadForm form) => Shape({
    for (final corner in positions) corner: Quadrant([LayerPiece(form)]),
  });

  Shape column(List<LayerPiece> layers) =>
      Shape({for (final corner in positions) corner: Quadrant(layers)});

  /// What the tray gains when [column] is cut off the plate.
  List<Shape> bankedFrom(Shape column) {
    final halves = [
      Shape({Corner.tl: column[Corner.tl], Corner.tr: column[Corner.tr]}),
      Shape({Corner.bl: column[Corner.bl], Corner.br: column[Corner.br]}),
    ];
    return [
      for (final half in halves)
        if (half.isNotEmpty) half,
    ];
  }
}
