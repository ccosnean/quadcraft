import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/core/level/endless/build_planner.dart';
import 'package:quadcraft/core/level/endless/seed_random.dart';
import 'package:quadcraft/core/level/game_state.dart';
import 'package:quadcraft/core/level/level.dart';
import 'package:quadcraft/core/shape/shape.dart';

/// Builds the level the planner just described and runs its line through the
/// real engine.
GameState? run(String start, String goal, List<QuadColor> palette) {
  final plan = BuildPlanner.plan(
    start: Shape.parse(start),
    goal: Shape.parse(goal),
    palette: palette,
  );
  if (plan == null) return null;
  final level = Level(
    number: 1,
    name: 'probe',
    section: 'probe',
    brief: 'probe',
    goal: Shape.parse(goal),
    start: Shape.parse(start),
    tray: plan.tray,
    colors: palette,
    canRotate: plan.usesRotate,
    canCut: plan.usesCut,
    solution: plan.moves,
  );
  return GameEngine.replay(level, level.solution);
}

void solves(String start, String goal, [List<QuadColor> palette = const []]) {
  final state = run(start, goal, palette);
  expect(state, isNotNull, reason: 'no plan for $start -> $goal');
  expect(
    state!.board.id,
    Shape.parse(goal).id,
    reason: 'plan for $start -> $goal landed on ${state.board.id}',
  );
  expect(state.solved, isTrue);
}

const r = QuadColor.red;
const b = QuadColor.blue;
const y = QuadColor.yellow;
const g = QuadColor.green;

void main() {
  group('bare plate', () {
    test('one piece in one corner', () => solves('-/-/-/-', 'Cu/-/-/-'));
    test('a far corner needs turns', () => solves('-/-/-/-', '-/-/Cu/-'));
    test('all four corners', () => solves('-/-/-/-', 'Su/Su/Su/Su'));
    test('a mirrored pair', () => solves('-/-/-/-', 'Cu/Cu/-/-'));
    test('a diagonal pair', () => solves('-/-/-/-', 'Cu/-/-/Cu'));
    test('four full stacks', () {
      solves('-/-/-/-', 'Wu+Tu+Su+Cu/Wu+Tu+Su+Cu/Wu+Tu+Su+Cu/Wu+Tu+Su+Cu');
    });
    test('one colour washes the whole plate', () {
      solves('-/-/-/-', 'Sr+Cr/Sr+Cr/Sr+Cr/Sr+Cr', [r]);
    });
    test('rings of colour', () {
      solves('-/-/-/-', 'Sr+Cb/Sr+Cb/Sr+Cb/Sr+Cb', [r, b]);
    });
    test('a colour per corner', () {
      solves('-/-/-/-', 'Cr/Cb/Cy/Cg', [r, b, y, g]);
    });
    test('colour mixed with bare pieces', () {
      solves('-/-/-/-', 'Sr+Cu/-/Su+Cr/-', [r]);
    });
  });

  group('a gift on the plate', () {
    test('one finished corner', () => solves('Cr/-/-/-', 'Cr/Su/-/-'));
    test('two on a diagonal', () => solves('Cr/-/-/Cb', 'Cr/Su/-/Cb'));
    test('two on a row', () => solves('Cr/Cb/-/-', 'Cr/Cb/Su/Su'));
    test('two in a column', () => solves('Cr/-/Cb/-', 'Cr/Su/Cb/-'));
    test('all four finished but one', () {
      solves('Cr/Cr/Cr/-', 'Cr/Cr/Cr/Su');
    });
    test('a colour the level cannot mix survives the coat', () {
      // Magenta is not in the palette: the only way to keep it is to bank it
      // before the blue goes on.
      solves('Cm/-/-/-', 'Cm/Cb/-/-', [b]);
    });
    test('an outer shell still missing its lining', () {
      solves('Wm/-/-/-', 'Wm+Su+Cu/-/-/-');
    });
    test('a shell on every corner', () {
      solves('Wm/Wm/Wm/Wm', 'Wm+Cb/Wm+Cb/Wm+Cb/Wm+Cb', [b]);
    });
    test('a shell over a coloured lining', () {
      solves('Wm/-/Wm/-', 'Wm+Sr+Cb/-/Wm+Sr+Cb/-', [r, b]);
    });
  });

  group('refuses what it cannot build', () {
    test('a plate holding something the goal does not want', () {
      expect(run('Cu/-/-/-', 'Su/-/-/-', const []), isNull);
    });
    test('a plate piece buried under the goal', () {
      // The gift would have to end up inside the finished stack, and drops
      // only ever go underneath.
      expect(run('Cu/-/-/-', 'Su+Cu/-/-/-', const []), isNull);
    });
    test('a colour the level was never given', () {
      expect(run('-/-/-/-', 'Cr/-/-/-', const [b]), isNull);
    });
    test('a goal already on the plate', () {
      expect(run('Cu/-/-/-', 'Cu/-/-/-', const []), isNull);
    });
  });

  test('every plan it hands back is a plan that finishes', () {
    // Sweep the space the designer draws from and hold the planner to its
    // contract: it either refuses, or it returns a line that solves.
    const forms = [QuadForm.circle, QuadForm.square, QuadForm.star];
    const colors = [QuadColor.uncolored, r, b];
    final rng = SeedRandom(20260828);
    var planned = 0;

    for (var trial = 0; trial < 3000; trial++) {
      final corners = <Corner, List<LayerPiece>>{};
      for (final corner in Corner.values) {
        if (rng.chance(0.45)) continue;
        corners[corner] = [
          for (var i = 0; i < rng.range(1, 4); i++)
            LayerPiece(rng.pick(forms), rng.pick(colors)),
        ];
      }
      if (corners.isEmpty) continue;
      final goal = Shape({
        for (final entry in corners.entries) entry.key: Quadrant(entry.value),
      });

      final start = Shape({
        for (final entry in corners.entries)
          if (rng.chance(0.3))
            entry.key: Quadrant(
              entry.value.sublist(0, rng.range(1, entry.value.length)),
            ),
      });

      final palette = <QuadColor>[
        for (final color in colors)
          if (color != QuadColor.uncolored && rng.chance(0.8)) color,
      ];

      final plan = BuildPlanner.plan(
        start: start,
        goal: goal,
        palette: palette,
      );
      if (plan == null) continue;
      planned++;

      final level = Level(
        number: 1,
        name: 'probe',
        section: 'probe',
        brief: 'probe',
        goal: goal,
        start: start,
        tray: plan.tray,
        colors: palette,
        canRotate: plan.usesRotate,
        canCut: plan.usesCut,
        solution: plan.moves,
      );
      final done = GameEngine.replay(level, level.solution);
      expect(
        done.solved,
        isTrue,
        reason:
            'start ${start.id} goal ${goal.id} palette '
            '${palette.map((c) => c.code).join()} ended ${done.board.id}',
      );
    }

    expect(planned, greaterThan(500), reason: 'the sweep barely planned');
  });
}
