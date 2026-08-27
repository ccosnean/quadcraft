import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/core/level/game_state.dart';
import 'package:quadcraft/core/level/level.dart';
import 'package:quadcraft/core/level/levels.dart';
import 'package:quadcraft/core/shape/shape.dart';
import 'package:quadcraft/l10n/l10n.dart';
import 'package:quadcraft/l10n/level_briefs.dart';

void main() {
  test('levels are numbered 1..n without gaps', () {
    for (var i = 0; i < kLevels.length; i++) {
      expect(kLevels[i].number, i + 1);
    }
    expect(kLevels.length, greaterThanOrEqualTo(15));
  });

  test('post-tutorial sections get longer', () {
    final sections = kLevelSections
        .where((entry) => !entry.key.startsWith('Tutorial'))
        .toList();
    expect(sections.length, greaterThanOrEqualTo(2));
    double? previousAvg;
    for (final entry in sections) {
      final avg =
          entry.value.map((level) => level.parMoves).reduce((a, b) => a + b) /
          entry.value.length;
      if (previousAvg != null) {
        expect(
          avg,
          greaterThan(previousAvg),
          reason:
              '${entry.key} avg par ${avg.toStringAsFixed(1)} '
              'should exceed previous ${previousAvg.toStringAsFixed(1)}',
        );
      }
      previousAvg = avg;
    }
  });

  group('every shipped level', () {
    for (final level in kLevels) {
      group('${level.number} ${level.name}', () {
        test('is solved by its reference line', () {
          final result = GameEngine.replay(level, level.solution);
          expect(
            result.solved,
            isTrue,
            reason: 'ended on ${result.board.id}, wanted ${level.goal.id}',
          );
          expect(result.moves, level.parMoves);
        });

        test('does not start solved', () {
          expect(GameState.initial(level).solved, isFalse);
        });

        test('has a reachable goal within the layer cap', () {
          expect(level.goal.isNotEmpty, isTrue);
          expect(level.goal.depth, lessThanOrEqualTo(Shape.maxLayers));
        });

        test('marks teaching flags for tools used in the solution', () {
          for (final move in level.solution) {
            switch (move) {
              case RotateMove():
                expect(
                  level.canRotate,
                  isTrue,
                  reason: 'rotate used but not marked as taught',
                );
              case CutMove():
                expect(
                  level.canCut,
                  isTrue,
                  reason: 'cut used but not marked as taught',
                );
              case PaintMove(:final color):
                expect(level.colors, contains(color));
              case StackMove():
                break;
            }
          }
        });

        test('has authored copy', () {
          expect(level.name.trim(), isNotEmpty);
          expect(level.brief.trim(), isNotEmpty);
        });
      });
    }
  });

  test('mechanics are introduced one at a time', () {
    var rotateSeen = false;
    var cutSeen = false;
    var paintSeen = false;
    for (final level in kLevels) {
      rotateSeen |= level.canRotate;
      cutSeen |= level.canCut;
      paintSeen |= level.colors.isNotEmpty;
    }
    expect(rotateSeen && cutSeen && paintSeen, isTrue);
    // Cutting is the most complex verb, so it must not appear first.
    expect(kLevels.first.canCut, isFalse);
  });

  group('engine rules', () {
    // Slice: full-plate circle tray, cut taught, no green paint.
    final level = levelByNumber(16);

    test('rejects a blueprint that is not in the tray', () {
      final outcome = GameEngine.apply(
        GameState.initial(level),
        const StackMove('Ty/Ty/Ty/Ty'),
        level,
      );
      expect(outcome.isApplied, isFalse);
      expect(outcome.rejection, MoveRejection.unknownBlueprint);
    });

    test('allows rotate even before the teaching accent is set', () {
      final early = levelByNumber(4);
      expect(early.canRotate, isFalse);
      var state = GameState.initial(early);
      // Give the board something to turn.
      state = GameEngine.apply(
        state,
        StackMove(early.tray.first.id),
        early,
      ).state!;
      final outcome = GameEngine.apply(state, const RotateMove(), early);
      expect(outcome.isApplied, isTrue);
    });

    test('rejects cut on an empty board', () {
      final outcome = GameEngine.apply(
        GameState.initial(level),
        const CutMove(),
        level,
      );
      expect(outcome.rejection, MoveRejection.boardEmpty);
    });

    test('cut banks both halves in the tray exactly once', () {
      var state = GameState.initial(level);
      state = GameEngine.apply(
        state,
        const StackMove('Cu/Cu/Cu/Cu'),
        level,
      ).state!;
      final outcome = GameEngine.apply(state, const CutMove(), level);
      expect(outcome.discovered.map((s) => s.id), ['Cu/Cu/-/-', '-/-/Cu/Cu']);
      expect(outcome.state!.board.isEmpty, isTrue);
      expect(outcome.state!.tray.length, 3);

      // Cutting the same shape again must not duplicate tray entries.
      var again = GameEngine.apply(
        outcome.state!,
        const StackMove('Cu/Cu/Cu/Cu'),
        level,
      ).state!;
      again = GameEngine.apply(again, const CutMove(), level).state!;
      expect(again.tray.length, 3);
    });

    test('counts one move per accepted action', () {
      var state = GameState.initial(level);
      expect(state.moves, 0);
      state = GameEngine.apply(
        state,
        const StackMove('Cu/Cu/Cu/Cu'),
        level,
      ).state!;
      expect(state.moves, 1);
      final rejected = GameEngine.apply(
        state,
        const PaintMove(QuadColor.green),
        level,
      );
      expect(rejected.state, isNull);
      expect(state.moves, 1);
    });
  });

  test('every non-English UI language has a brief for every level', () {
    final numbers = {for (final level in kLevels) level.number};
    final localized = AppLanguage.values.where((l) => l != AppLanguage.en);
    expect(kLevelBriefs.keys.toSet(), {
      for (final language in localized) language.code,
    });
    for (final language in localized) {
      final briefs = kLevelBriefs[language.code]!;
      expect(briefs.keys.toSet(), numbers, reason: language.code);
      for (final level in kLevels) {
        expect(briefs[level.number]!.trim(), isNotEmpty, reason: language.code);
        expect(briefs[level.number], isNot(level.brief), reason: language.code);
      }
    }
  });
}
