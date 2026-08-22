import 'shape.dart';

/// The two halves produced by a horizontal cut.
typedef CutResult = ({Shape top, Shape bottom});

/// Pure shape algebra. Every board mutation in the game goes through one of
/// these functions, which keeps the rules testable and the UI dumb.
abstract final class ShapeOps {
  /// Rotates the shape a quarter turn clockwise: tl to tr, tr to br, and so on.
  static Shape rotateClockwise(Shape shape) => Shape({
        Corner.tr: shape[Corner.tl],
        Corner.br: shape[Corner.tr],
        Corner.bl: shape[Corner.br],
        Corner.tl: shape[Corner.bl],
      });

  static Shape rotateCounterClockwise(Shape shape) => Shape({
        Corner.tl: shape[Corner.tr],
        Corner.tr: shape[Corner.br],
        Corner.br: shape[Corner.bl],
        Corner.bl: shape[Corner.tl],
      });

  /// Slices the shape along its horizontal axis. Each half keeps the quadrant
  /// positions it already had, so rotation is the only way to move pieces
  /// between rows.
  static CutResult cutHorizontal(Shape shape) => (
        top: Shape({Corner.tl: shape[Corner.tl], Corner.tr: shape[Corner.tr]}),
        bottom: Shape({Corner.bl: shape[Corner.bl], Corner.br: shape[Corner.br]}),
      );

  /// Whether [incoming] can be dropped onto [board] without any quadrant
  /// exceeding [Shape.maxLayers].
  static bool canStack(Shape board, Shape incoming) {
    if (incoming.isEmpty) return false;
    return overflowingCorners(board, incoming).isEmpty;
  }

  /// Quadrants that would exceed the layer cap if [incoming] were stacked.
  static Set<Corner> overflowingCorners(Shape board, Shape incoming) => {
        for (final corner in Corner.values)
          if (board[corner].depth + incoming[corner].depth > Shape.maxLayers) corner,
      };

  /// Drops [incoming] onto [board]. The incoming piece slides *underneath*
  /// whatever already occupies a quadrant, pushing the existing stack inward
  /// so it renders smaller.
  static Shape stack(Shape board, Shape incoming) {
    assert(canStack(board, incoming), 'stack() called on an invalid drop');
    return Shape({
      for (final corner in Corner.values)
        corner: Quadrant([...incoming[corner].layers, ...board[corner].layers]),
    });
  }

  /// Paints every piece on the board. Paint is global by design: colouring one
  /// quadrant differently requires cutting pieces aside first.
  static Shape paintAll(Shape shape, QuadColor color) => Shape({
        for (final corner in Corner.values) corner: shape[corner].painted(color),
      });

  /// True when painting would actually change something.
  static bool canPaint(Shape shape, QuadColor color) =>
      shape.isNotEmpty && paintAll(shape, color).id != shape.id;

  static bool shapesEqual(Shape a, Shape b) => a.id == b.id;
}
