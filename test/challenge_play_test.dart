import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/level/level.dart';
import 'package:quadcraft/core/level/level_catalog.dart';
import 'package:quadcraft/core/shape/shape.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/play/play_controller.dart';

void main() {
  late ProviderContainer container;
  late MemoryProgressStore store;

  setUp(() {
    store = MemoryProgressStore();
    container = ProviderContainer(
      overrides: [
        progressStoreProvider.overrideWithValue(store),
        soundBankProvider.overrideWithValue(SoundBank.silent()),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Plays the level's own reference line through the controller, which is
  /// the only way to finish a generated level without solving it by hand.
  void solve(LevelRef ref) {
    final controller = container.read(playControllerProvider(ref).notifier);
    for (final move in levelFor(ref).solution) {
      switch (move) {
        case RotateMove():
          controller.rotate();
        case CutMove():
          controller.cut();
        case StackMove(:final shapeId):
          controller.drop(Shape.parse(shapeId));
        case PaintMove(:final color):
          controller.paint(color);
      }
    }
  }

  test('a campaign level cleared normally is recorded', () {
    solve(const LevelRef.campaign(1));
    expect(
      container.read(playControllerProvider(const LevelRef.campaign(1))).solved,
      isTrue,
    );
    expect(store.recordFor(1), isNotNull);
  });

  test('the same level cleared from a code is not', () {
    const ref = LevelRef.campaign(1, isChallenge: true);
    solve(ref);

    final state = container.read(playControllerProvider(ref));
    expect(state.solved, isTrue);
    // The sheet still reports the attempt — it just has nothing behind it.
    expect(state.clear, isNotNull);
    expect(state.clear!.moves, state.scoredMoves);
    expect(state.clear!.isFirstClear, isFalse);
    expect(store.recordFor(1), isNull);
    expect(store.allRecords(), isEmpty);
  });

  test('clearing somebody else\'s depth leaves the dive exactly as it was', () {
    final before = store.diveRun();
    expect(before.seed, isNot(4242));

    solve(LevelRef.endless(seed: 4242, number: 3, isChallenge: true));

    final after = store.diveRun();
    expect(after.seed, before.seed);
    expect(after.depth, before.depth);
    expect(after.deepest, before.deepest);
    expect(after.clears, before.clears);
    expect(store.allDiveRecords(), isEmpty);
    // Not even the collection: a target you met on a stranger's ladder is not
    // one this run turned up.
    expect(store.discoveries(), isEmpty);
  });

  test('the same depth on your own run is recorded', () {
    final seed = store.diveRun().seed;
    solve(LevelRef.endless(seed: seed, number: 1));

    expect(store.allDiveRecords(), hasLength(1));
    expect(store.diveRun().deepest, 1);
    expect(store.discoveries(), isNotEmpty);
  });
}
