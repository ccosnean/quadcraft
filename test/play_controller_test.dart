import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/level/level.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/play/play_controller.dart';

void main() {
  late ProviderContainer container;
  late MemoryProgressStore store;

  PlayController controller(int level) =>
      container.read(playControllerProvider(LevelRef.campaign(level)).notifier);

  PlayState play(int level) =>
      container.read(playControllerProvider(LevelRef.campaign(level)));

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

  test('a hint costs a scored move without touching the board', () {
    expect(controller(1).revealHint(), isA<RotateMove>());
    final state = play(1);
    expect(state.hintsUsed, 1);
    expect(state.game.moves, 0);
    expect(state.scoredMoves, 1);
    expect(state.game.board.id, state.level.start.id);
  });

  test('three hints per attempt, then no more', () {
    for (var i = 0; i < kMaxHintsPerLevel; i++) {
      expect(controller(1).revealHint(), isA<RotateMove>());
    }
    expect(controller(1).revealHint(), isNull);
    expect(play(1).hintsUsed, kMaxHintsPerLevel);
    expect(play(1).canHint, isFalse);
    expect(play(1).scoredMoves, kMaxHintsPerLevel);
  });

  test('reset keeps the hint spend', () {
    controller(1).revealHint();
    controller(1).rotate();
    controller(1).reset();
    expect(play(1).game.moves, 0);
    expect(play(1).hintsUsed, 1);
    expect(play(1).scoredMoves, 1);
    expect(play(1).hintsRemaining, kMaxHintsPerLevel - 1);
  });

  test('clear records the hint tax', () {
    controller(1).revealHint();
    controller(1).rotate();
    expect(play(1).solved, isTrue);
    expect(store.recordFor(1)!.bestMoves, 2);
  });
}
