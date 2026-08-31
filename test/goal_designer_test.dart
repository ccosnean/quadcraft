import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/core/level/endless/designers/goal_designer_v1.dart';
import 'package:quadcraft/core/level/endless/endless_tuning.dart';
import 'package:quadcraft/core/level/endless/goal_designer.dart';
import 'package:quadcraft/core/level/endless/seed_random.dart';
import 'package:quadcraft/core/shape/shape.dart';

const _mirrorH = {
  Corner.tl: Corner.tr,
  Corner.tr: Corner.tl,
  Corner.bl: Corner.br,
  Corner.br: Corner.bl,
};
const _mirrorV = {
  Corner.tl: Corner.bl,
  Corner.bl: Corner.tl,
  Corner.tr: Corner.br,
  Corner.br: Corner.tr,
};
const _halfTurn = {
  Corner.tl: Corner.br,
  Corner.br: Corner.tl,
  Corner.tr: Corner.bl,
  Corner.bl: Corner.tr,
};

bool _invariant(Shape shape, Map<Corner, Corner> under) {
  for (final corner in Corner.values) {
    if (shape[corner] != shape[under[corner]!]) return false;
  }
  return true;
}

/// Whether a mirror or a half turn maps the whole target onto itself.
bool isExactlySymmetric(Shape shape) =>
    _invariant(shape, _mirrorH) ||
    _invariant(shape, _mirrorV) ||
    _invariant(shape, _halfTurn);

/// Whether any two filled corners carry the same stack. Weaker than a
/// symmetry, and the only kind of order a three-cornered target can hold.
bool hasMatchedPair(Shape shape) {
  final filled = shape.filledCorners.toList();
  for (var i = 0; i < filled.length; i++) {
    for (var j = i + 1; j < filled.length; j++) {
      if (shape[filled[i]] == shape[filled[j]]) return true;
    }
  }
  return false;
}

/// How many distinct stacks a target uses. Gifts are handed out per class, so
/// this is the stratum any comparison between gifted and ungifted has to hold
/// fixed to mean anything.
int _stackClasses(Shape shape) =>
    {for (final corner in shape.filledCorners) shape[corner]}.length;

/// Every draft across a spread of depths, for census-style assertions.
List<LevelDraft> _census({int perDepth = 300}) {
  const depths = [5, 10, 15, 20, 25, 30, 40, 60, 90];
  return [
    for (final depth in depths)
      for (var seed = 1; seed <= perDepth; seed++)
        GoalDesigners.current.draft(
          SeedRandom(mixSeed([seed, depth, 17])),
          EndlessTuning.forDepth(depth),
        ),
  ];
}

void main() {
  group('the designer registry', () {
    test('v1 is what the dive is drawn with', () {
      expect(GoalDesigners.current, same(GoalDesigners.v1));
      expect(GoalDesigners.v1.id, 'v1');
      expect(GoalDesigners.all, contains(GoalDesigners.v1));
      expect(GoalDesigners.all.map((d) => d.id).toSet().length,
          GoalDesigners.all.length,
          reason: 'ids must be unique, they address a saved run');
    });

    test('an unknown id falls back rather than refusing to load', () {
      expect(GoalDesigners.byId('v1'), same(GoalDesigners.v1));
      expect(GoalDesigners.byId('v99-from-the-future'),
          same(GoalDesigners.current));
    });

    test('a designer is deterministic for a seed', () {
      const designer = GoalDesignerV1();
      final tuning = EndlessTuning.forDepth(21);
      for (var seed = 1; seed <= 40; seed++) {
        final a = designer.draft(SeedRandom(seed), tuning);
        final b = designer.draft(SeedRandom(seed), tuning);
        expect(a.goal, b.goal, reason: 'seed $seed');
        expect(a.start, b.start, reason: 'seed $seed');
      }
    });
  });

  group('symmetry', () {
    test('most targets are drawn on one', () {
      // The bug this guards against: the corner count used to be rolled before
      // the symmetry, from a range that is {3, 4} for most of the ladder. A
      // three-cornered target cannot be invariant under any mirror or half
      // turn, so half of every batch was incapable of symmetry before the
      // symmetry roll was even reached. Measured symmetry was 29%.
      final drafts = _census();
      final exact = drafts.where((d) => isExactlySymmetric(d.goal)).length;
      final ordered = drafts
          .where((d) => isExactlySymmetric(d.goal) || hasMatchedPair(d.goal))
          .length;
      final exactRate = exact / drafts.length;
      final orderedRate = ordered / drafts.length;

      expect(exactRate, greaterThan(0.55), reason: 'exact was $exactRate');
      expect(orderedRate, greaterThan(0.85), reason: 'ordered was $orderedRate');
    });

    test('a gift never breaks the symmetry it was cut from', () {
      // The second bug: gifts were handed out per corner, so dyeing one corner
      // of a mirrored pair a relic colour took a target drawn on a mirror and
      // left it lopsided.
      //
      // Compared within a stratum of equal class count, not in aggregate. A
      // target whose corners all match cannot take a finished-corner gift —
      // nothing would be left to build — so those, which are also the most
      // symmetric targets there are, are mostly ungifted. In aggregate that
      // selection alone shows an 18-point gap even when gifting is perfectly
      // symmetry-preserving, which is enough to hide or invent a real one.
      var giftedTotal = 0, giftedExact = 0, plainTotal = 0, plainExact = 0;
      for (final draft in _census()) {
        // Two distinct stacks over the corners: the stratum where gifting has
        // a real choice to make, and where breaking a pair would show.
        if (_stackClasses(draft.goal) != 2) continue;
        final exact = isExactlySymmetric(draft.goal);
        if (draft.start.isNotEmpty) {
          giftedTotal++;
          if (exact) giftedExact++;
        } else {
          plainTotal++;
          if (exact) plainExact++;
        }
      }
      expect(giftedTotal, greaterThan(200), reason: 'need gifted drafts');
      expect(plainTotal, greaterThan(200), reason: 'need ungifted drafts');

      final giftedRate = giftedExact / giftedTotal;
      final plainRate = plainExact / plainTotal;
      expect(
        giftedRate,
        greaterThan(plainRate - 0.10),
        reason: 'gifted $giftedRate vs ungifted $plainRate at 2 classes',
      );
    });

    test('a gift covers every corner that looks the same', () {
      for (final draft in _census(perDepth: 120)) {
        if (draft.start.isEmpty) continue;
        // Wherever two corners share a goal stack, they must share a start
        // stack as well — otherwise the head start is visibly one-sided.
        for (final a in Corner.values) {
          for (final b in Corner.values) {
            if (a == b) continue;
            if (draft.goal[a].isEmpty || draft.goal[a] != draft.goal[b]) {
              continue;
            }
            expect(
              draft.start[a],
              draft.start[b],
              reason: 'corners $a and $b share a stack but not a gift',
            );
          }
        }
      }
    });

    test('order loosens as the dive deepens', () {
      double exactAt(int depth) {
        final tuning = EndlessTuning.forDepth(depth);
        var hits = 0;
        for (var seed = 1; seed <= 500; seed++) {
          final draft = GoalDesigners.current.draft(
            SeedRandom(mixSeed([seed, depth, 3])),
            tuning,
          );
          if (isExactlySymmetric(draft.goal)) hits++;
        }
        return hits / 500;
      }

      // Shallow water is orderly; the deep end is allowed to be strange.
      expect(exactAt(5), greaterThan(exactAt(90) + 0.15));
    });

    test('not everything is a full plate', () {
      // Exact symmetry needs two or four filled corners, so leaning on it also
      // leans on full plates. Odd-cornered targets have to survive, or the
      // whole ladder ends up with one silhouette.
      final drafts = _census();
      final odd =
          drafts.where((d) => d.goal.filledCorners.length.isOdd).length;
      expect(odd / drafts.length, greaterThan(0.08),
          reason: 'odd-cornered targets have been squeezed out');
    });
  });
}
