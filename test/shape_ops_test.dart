import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/core/shape/shape.dart';
import 'package:quadcraft/core/shape/shape_ops.dart';

void main() {
  group('shape dsl', () {
    test('parse and id round-trip', () {
      const ids = [
        '-/-/-/-',
        'Cu/-/-/-',
        'Cu/Cu/Cu/Cu',
        'Su+Cu/-/-/-',
        'Wu+Tu+Su+Cr/Cb/-/Ty',
        'Po/Po/Po/Po',
        'Lm+Cr/Lm+Cr/Lm+Cr/Lm+Cr',
      ];
      for (final id in ids) {
        expect(Shape.parse(id).id, id);
      }
    });

    test('empty shape reports four empty quadrants', () {
      expect(Shape.empty.isEmpty, isTrue);
      expect(Shape.empty.id, '-/-/-/-');
      for (final corner in Corner.values) {
        expect(Shape.empty[corner].isEmpty, isTrue);
      }
    });

    test('equality is structural', () {
      expect(
        Shape.parse('Cr/-/-/-'),
        Shape.single(Corner.tl, QuadForm.circle, QuadColor.red),
      );
      expect(Shape.parse('Cr/-/-/-') == Shape.parse('Cb/-/-/-'), isFalse);
      expect(Shape.uniform(QuadForm.square).id, 'Su/Su/Su/Su');
    });

    test('rejects malformed input', () {
      expect(() => Shape.parse('Cu/-/-'), throwsFormatException);
      expect(() => Shape.parse('Xu/-/-/-'), throwsFormatException);
      expect(() => Shape.parse('C/-/-/-'), throwsFormatException);
    });

    test('counts pieces and depth', () {
      final shape = Shape.parse('Su+Cu/Cu/-/-');
      expect(shape.pieceCount, 3);
      expect(shape.depth, 2);
      expect(shape.filledCorners, [Corner.tl, Corner.tr]);
    });
  });

  group('rotate', () {
    test('moves each quadrant one step clockwise', () {
      expect(ShapeOps.rotateClockwise(Shape.parse('Cu/-/-/-')).id, '-/Cu/-/-');
      expect(ShapeOps.rotateClockwise(Shape.parse('-/Cu/-/-')).id, '-/-/-/Cu');
      expect(ShapeOps.rotateClockwise(Shape.parse('-/-/-/Cu')).id, '-/-/Cu/-');
      expect(ShapeOps.rotateClockwise(Shape.parse('-/-/Cu/-')).id, 'Cu/-/-/-');
    });

    test('four turns is the identity', () {
      final start = Shape.parse('Su+Cu/Cr/-/Tb');
      var shape = start;
      for (var i = 0; i < 4; i++) {
        shape = ShapeOps.rotateClockwise(shape);
      }
      expect(shape.id, start.id);
    });

    test('counter-clockwise undoes clockwise', () {
      final start = Shape.parse('Su/Cr/Tb/-');
      expect(
        ShapeOps.rotateCounterClockwise(ShapeOps.rotateClockwise(start)).id,
        start.id,
      );
    });

    test('preserves layer order inside a quadrant', () {
      expect(
        ShapeOps.rotateClockwise(Shape.parse('Su+Cu/-/-/-')).id,
        '-/Su+Cu/-/-',
      );
    });
  });

  group('cut', () {
    test('splits rows and keeps quadrant positions', () {
      final halves = ShapeOps.cutHorizontal(Shape.parse('Cu/Su/Tu/Wu'));
      expect(halves.top.id, 'Cu/Su/-/-');
      expect(halves.bottom.id, '-/-/Tu/Wu');
    });

    test('yields an empty half when a row is empty', () {
      final halves = ShapeOps.cutHorizontal(Shape.parse('Cu/Cu/-/-'));
      expect(halves.top.id, 'Cu/Cu/-/-');
      expect(halves.bottom.isEmpty, isTrue);
    });

    test('keeps colours and stacks intact', () {
      final halves = ShapeOps.cutHorizontal(Shape.parse('Sb+Cr/-/-/Ty'));
      expect(halves.top.id, 'Sb+Cr/-/-/-');
      expect(halves.bottom.id, '-/-/-/Ty');
    });
  });

  group('stack', () {
    test('fills empty quadrants', () {
      final result = ShapeOps.stack(
        Shape.parse('Cu/-/-/-'),
        Shape.parse('-/Su/-/-'),
      );
      expect(result.id, 'Cu/Su/-/-');
    });

    test('incoming piece lands under the existing stack', () {
      final result = ShapeOps.stack(
        Shape.parse('Cu/-/-/-'),
        Shape.parse('Su/-/-/-'),
      );
      expect(result.id, 'Su+Cu/-/-/-');
      expect(result[Corner.tl].layers.first.form, QuadForm.square);
      expect(result[Corner.tl].layers.last.form, QuadForm.circle);
    });

    test('repeated drops keep pushing the older pieces inward', () {
      var board = Shape.parse('Cu/-/-/-');
      board = ShapeOps.stack(board, Shape.parse('Su/-/-/-'));
      board = ShapeOps.stack(board, Shape.parse('Tu/-/-/-'));
      board = ShapeOps.stack(board, Shape.parse('Wu/-/-/-'));
      expect(board.id, 'Wu+Tu+Su+Cu/-/-/-');
      expect(board.depth, Shape.maxLayers);
    });

    test('refuses a drop that would exceed the layer cap', () {
      final full = Shape.parse('Wu+Tu+Su+Cu/-/-/-');
      expect(ShapeOps.canStack(full, Shape.parse('Cu/-/-/-')), isFalse);
      expect(ShapeOps.overflowingCorners(full, Shape.parse('Cu/-/-/-')), {
        Corner.tl,
      });
      // A drop that misses the full quadrant is still fine.
      expect(ShapeOps.canStack(full, Shape.parse('-/Cu/-/-')), isTrue);
    });

    test('reports every overflowing quadrant', () {
      final board = Shape.parse('Wu+Tu+Su+Cu/Wu+Tu+Su+Cu/-/-');
      expect(ShapeOps.overflowingCorners(board, Shape.parse('Cu/Cu/Cu/-')), {
        Corner.tl,
        Corner.tr,
      });
    });

    test('an empty blueprint is not a legal drop', () {
      expect(ShapeOps.canStack(Shape.parse('Cu/-/-/-'), Shape.empty), isFalse);
    });
  });

  group('paint', () {
    test('colours every layer of every filled quadrant', () {
      expect(
        ShapeOps.paintAll(Shape.parse('Su+Cu/Cu/-/-'), QuadColor.red).id,
        'Sr+Cr/Cr/-/-',
      );
    });

    test('leaves empty quadrants empty', () {
      expect(ShapeOps.paintAll(Shape.empty, QuadColor.red).id, '-/-/-/-');
      expect(ShapeOps.canPaint(Shape.empty, QuadColor.red), isFalse);
    });

    test('repainting the same colour is a no-op', () {
      final red = Shape.parse('Cr/Cr/-/-');
      expect(ShapeOps.canPaint(red, QuadColor.red), isFalse);
      expect(ShapeOps.canPaint(red, QuadColor.blue), isTrue);
    });

    test('overwrites mixed colours uniformly', () {
      expect(
        ShapeOps.paintAll(Shape.parse('Cb+Cr/Ty/-/-'), QuadColor.green).id,
        'Cg+Cg/Tg/-/-',
      );
    });
  });

  test('shapesEqual compares canonical ids', () {
    expect(
      ShapeOps.shapesEqual(
        Shape.parse('Cu/-/-/-'),
        Shape.single(Corner.tl, QuadForm.circle),
      ),
      isTrue,
    );
    expect(
      ShapeOps.shapesEqual(Shape.parse('Cu/-/-/-'), Shape.parse('-/Cu/-/-')),
      isFalse,
    );
  });
}
