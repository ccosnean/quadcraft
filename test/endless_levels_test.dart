import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/core/level/endless/endless_levels.dart';
import 'package:quadcraft/core/level/endless/endless_tuning.dart';
import 'package:quadcraft/core/level/game_state.dart';
import 'package:quadcraft/core/level/level.dart';
import 'package:quadcraft/core/shape/shape.dart';

const _seeds = [1, 42, 991, 123456, 777777];
const _deepest = 70;

Iterable<Level> everyLevel() sync* {
  for (final seed in _seeds) {
    for (var depth = 1; depth <= _deepest; depth++) {
      yield EndlessLevels.levelAt(seed: seed, depth: depth);
    }
  }
}

void main() {
  group('every generated level', () {
    test('is finished by the line it was built from', () {
      for (final level in everyLevel()) {
        final done = GameEngine.replay(level, level.solution);
        expect(
          done.solved,
          isTrue,
          reason:
              '${level.id} ended on ${done.board.id}, wanted ${level.goal.id}',
        );
        expect(done.moves, level.parMoves, reason: level.id);
      }
    });

    test('does not start solved and has something to build', () {
      for (final level in everyLevel()) {
        expect(GameState.initial(level).solved, isFalse, reason: level.id);
        expect(level.goal.isNotEmpty, isTrue, reason: level.id);
        expect(level.solution, isNotEmpty, reason: level.id);
        // A level may ship with an empty tray, but only when the plate itself
        // is the material — otherwise there is nothing to act on at all.
        expect(
          level.tray.isNotEmpty || level.start.isNotEmpty,
          isTrue,
          reason: level.id,
        );
      }
    });

    test('stays inside the layer cap', () {
      for (final level in everyLevel()) {
        expect(
          level.goal.depth,
          lessThanOrEqualTo(Shape.maxLayers),
          reason: level.id,
        );
        expect(
          level.goal.depth,
          lessThanOrEqualTo(EndlessTuning.forDepth(level.number).maxLayers),
          reason: level.id,
        );
      }
    });

    test('only starts with pieces the finished corner keeps outermost', () {
      for (final level in everyLevel()) {
        for (final corner in Corner.values) {
          final onPlate = level.start[corner].layers;
          final wanted = level.goal[corner].layers;
          expect(
            onPlate.length,
            lessThanOrEqualTo(wanted.length),
            reason: '${level.id} $corner',
          );
          for (var i = 0; i < onPlate.length; i++) {
            expect(
              onPlate[i],
              wanted[i],
              reason: '${level.id} $corner layer $i',
            );
          }
        }
      }
    });

    test('offers exactly the colours the player still has to mix', () {
      for (final level in everyLevel()) {
        final needed = <QuadColor>{
          for (final corner in Corner.values)
            for (final piece in level.goal[corner].layers.skip(
              level.start[corner].depth,
            ))
              if (piece.color != QuadColor.uncolored) piece.color,
        };
        expect(level.colors.toSet(), needed, reason: level.id);
      }
    });

    test('marks the tools its line actually uses', () {
      for (final level in everyLevel()) {
        for (final move in level.solution) {
          switch (move) {
            case RotateMove():
              expect(level.canRotate, isTrue, reason: level.id);
            case CutMove():
              expect(level.canCut, isTrue, reason: level.id);
            case PaintMove(:final color):
              expect(level.colors, contains(color), reason: level.id);
            case StackMove():
              break;
          }
        }
      }
    });

    test('never shows a form or colour the dive has not unlocked yet', () {
      for (final level in everyLevel()) {
        final forms = EndlessTuning.formsAt(level.number).toSet();
        final colors = EndlessTuning.colorsAt(level.number).toSet();
        for (final corner in Corner.values) {
          for (final piece in level.goal[corner].layers) {
            expect(forms, contains(piece.form), reason: level.id);
            if (piece.color != QuadColor.uncolored) {
              expect(colors, contains(piece.color), reason: level.id);
            }
          }
        }
      }
    });

    test('keeps the tray readable', () {
      for (final level in everyLevel()) {
        expect(level.tray.length, lessThanOrEqualTo(6), reason: level.id);
        // Blueprints are matched by id when dropped, so duplicates would be
        // dead weight the player cannot tell apart.
        expect(
          level.tray.map((shape) => shape.id).toSet().length,
          level.tray.length,
          reason: level.id,
        );
      }
    });
  });

  test('a run never repeats the target it just showed', () {
    // Regression: the designer used to draw each depth independently, so
    // nothing stopped two neighbouring depths from landing on the exact same
    // goal shape — which read as the dive being stuck rather than deepening.
    for (final seed in [..._seeds, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]) {
      EndlessLevels.clearCache();
      String? previous;
      String? twoAgo;
      for (var depth = 1; depth <= 40; depth++) {
        final goal = EndlessLevels.levelAt(seed: seed, depth: depth).goal.id;
        expect(
          goal,
          isNot(previous),
          reason: 'seed $seed depth $depth repeated depth ${depth - 1}',
        );
        expect(
          goal,
          isNot(twoAgo),
          reason: 'seed $seed depth $depth repeated depth ${depth - 2}',
        );
        twoAgo = previous;
        previous = goal;
      }
    }
  });

  test('a depth opened cold is the depth reached by diving to it', () {
    // A share code jumps straight to a depth on a device that has never seen
    // the ones above it, so a level must not depend on what the cache happens
    // to hold: the anti-repeat filter reads previously generated depths, and
    // if it ever changed which draft wins, every code already in the wild
    // would open a different puzzle than the one on the picture.
    for (var s = 0; s < 8; s++) {
      final seed = 100000 + s * 37199;

      EndlessLevels.clearCache();
      final walked = <int, String>{};
      for (var depth = 1; depth <= 30; depth++) {
        walked[depth] = EndlessLevels.levelAt(seed: seed, depth: depth).goal.id;
      }

      for (var depth = 1; depth <= 30; depth++) {
        EndlessLevels.clearCache();
        expect(
          EndlessLevels.levelAt(seed: seed, depth: depth).goal.id,
          walked[depth],
          reason: 'seed $seed depth $depth differs when opened cold',
        );
      }
    }
  });

  test('a different seed grows a genuinely different ladder', () {
    // Regression: the curve used to open so narrowly — one form, one layer,
    // one corner, no colour — that every seed produced the *same* first few
    // targets. Changing the seed looked like it did nothing. Depth 1 is the
    // level after the tutorial, so it has a full vocabulary to draw on and
    // seeds must diverge from the very first rung.
    const seeds = 40;
    for (final depth in [1, 2, 3, 5, 10, 20]) {
      final goals = <String>{};
      for (var i = 0; i < seeds; i++) {
        goals.add(
          EndlessLevels.levelAt(seed: 1000 + i * 7919, depth: depth).goal.id,
        );
      }
      expect(
        goals.length,
        greaterThan(seeds ~/ 2),
        reason:
            'depth $depth produced only ${goals.length} distinct targets '
            'across $seeds seeds',
      );
    }
  });

  test('a seed rebuilds the same dive every time', () {
    for (final seed in _seeds) {
      for (final depth in [1, 9, 23, 44, 61]) {
        EndlessLevels.clearCache();
        final first = EndlessLevels.levelAt(seed: seed, depth: depth);
        EndlessLevels.clearCache();
        final again = EndlessLevels.levelAt(seed: seed, depth: depth);
        expect(again.goal.id, first.goal.id);
        expect(again.start.id, first.start.id);
        expect(again.parMoves, first.parMoves);
        expect(
          again.tray.map((s) => s.id).toList(),
          first.tray.map((s) => s.id).toList(),
        );
        expect(again.theme, first.theme);
      }
    }
  });

  test('different seeds grow different dives', () {
    final goals = {
      for (final seed in _seeds)
        seed: [
          for (var depth = 5; depth <= 20; depth++)
            EndlessLevels.levelAt(seed: seed, depth: depth).goal.id,
        ],
    };
    for (final seed in _seeds.skip(1)) {
      expect(goals[seed], isNot(equals(goals[_seeds.first])));
    }
  });

  test('the dive gets longer as it gets deeper', () {
    double averagePar(int from, int to) {
      var total = 0;
      var count = 0;
      for (final seed in _seeds) {
        for (var depth = from; depth <= to; depth++) {
          total += EndlessLevels.levelAt(seed: seed, depth: depth).parMoves;
          count++;
        }
      }
      return total / count;
    }

    final bands = [
      averagePar(1, 6),
      averagePar(7, 14),
      averagePar(15, 24),
      averagePar(25, 40),
    ];
    for (var i = 1; i < bands.length; i++) {
      expect(
        bands[i],
        greaterThan(bands[i - 1]),
        reason: 'band $i averaged ${bands[i]}, previous ${bands[i - 1]}',
      );
    }
  });

  test('depth still generates far past anything a player will reach', () {
    for (final depth in [120, 500, 4321]) {
      final level = EndlessLevels.levelAt(seed: 8, depth: depth);
      expect(GameEngine.replay(level, level.solution).solved, isTrue);
      expect(level.stratum, (depth - 1) ~/ kStratumSpan);
    }
  });

  test('bands of the dive are named all the way down', () {
    expect(EndlessLevels.stratumName(0), 'The Shallows');
    expect(EndlessLevels.stratumName(5), 'Starfall');
    expect(EndlessLevels.stratumName(6), 'The Shallows 2');
    expect(EndlessLevels.stratumName(13), 'Brass Terrace 3');
  });

  test('the unlock ladder only ever points forward', () {
    var previous = 0;
    for (var depth = 1; depth <= 40; depth++) {
      final next = EndlessTuning.nextUnlock(depth);
      if (next == null) continue;
      expect(next.depth, greaterThan(depth));
      expect(next.depth, greaterThanOrEqualTo(previous));
      previous = next.depth;
    }
  });
}
