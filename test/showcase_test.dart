import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/core/level/endless/endless_levels.dart';
import 'package:quadcraft/core/shape/shape.dart';
import 'package:quadcraft/features/home/showcase.dart';

/// Pumps until the scan has run to the end, or gives up.
Future<ShowcaseShapes> settled(WidgetTester tester, int seed) async {
  final showcase = ShowcaseShapes(seed: seed);
  for (var frame = 0; frame < 400 && !showcase.isComplete; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(showcase.isComplete, isTrue, reason: 'scan never finished');
  return showcase;
}

void main() {
  setUp(EndlessLevels.clearCache);

  group('scoring', () {
    test('ranks four-fold symmetry above everything else', () {
      // The shape turns on the spot on the title screen, so the only symmetry
      // the animation itself does not break is the quarter turn.
      final quarter = Shape.parse('Cr/Cr/Cr/Cr');
      final mirror = Shape.parse('Cr/Cr/Cb/Cb');
      final pair = Shape.parse('Cr/Cr/Cb/Cg');
      final scattered = Shape.parse('Cr/Cb/Cg/Cy');

      expect(showcaseScore(quarter), greaterThan(showcaseScore(mirror)));
      expect(showcaseScore(mirror), greaterThan(showcaseScore(pair)));
      expect(showcaseScore(pair), greaterThan(showcaseScore(scattered)));
      expect(showcaseScore(Shape.empty), 0);
    });

    test('breaks ties towards something worth looking at', () {
      // Both are four-fold symmetric; one is a bare circle in one corner.
      final full = Shape.parse('Cr/Cr/Cr/Cr');
      final sparse = Shape.parse('Cr//Cr/');
      expect(showcaseScore(full), greaterThan(showcaseScore(sparse)));

      final layered = Shape.parse('Cr+Sb/Cr+Sb/Cr+Sb/Cr+Sb');
      expect(showcaseScore(layered), greaterThan(showcaseScore(full)));
    });
  });

  group('the title screen showcase', () {
    testWidgets('is one shape per complexity band, shallowest first', (
      tester,
    ) async {
      final showcase = await settled(tester, 20260830);
      expect(showcase.shapes, hasLength(showcaseCount));
    });

    testWidgets('is drawn from the run, so a new seed redraws it', (
      tester,
    ) async {
      final mine = await settled(tester, 111);
      EndlessLevels.clearCache();
      final yours = await settled(tester, 999);

      final a = mine.shapes.map((s) => s.id).toList();
      final b = yours.shapes.map((s) => s.id).toList();
      expect(a, isNot(b), reason: 'the showcase should be the run itself');
    });

    testWidgets('picks shapes that hold still while they turn', (tester) async {
      // The whole point of scoring: the front of the game should not be
      // showing the scrappiest thing the ladder happened to grow.
      var symmetric = 0;
      for (final seed in [7, 4242, 20260830]) {
        EndlessLevels.clearCache();
        final showcase = await settled(tester, seed);
        for (final shape in showcase.shapes) {
          // 100 per symmetry step, so anything mirrored or better clears 300.
          if (showcaseScore(shape) >= 300) symmetric++;
        }
      }
      final rate = symmetric / (3 * showcaseCount);
      expect(rate, greaterThan(0.75), reason: 'only $rate held still');
    });

    testWidgets('shows something before the scan has finished', (tester) async {
      final showcase = ShowcaseShapes(seed: 5150);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(showcase.shapes, isNotEmpty, reason: 'the title screen cannot wait');
      showcase.dispose();
    });
  });
}
