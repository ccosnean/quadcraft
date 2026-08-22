import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/level/levels.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/home/home_screen.dart';
import 'package:quadcraft/features/levels/level_select_screen.dart';
import 'package:quadcraft/features/play/play_controller.dart';
import 'package:quadcraft/features/play/play_screen.dart';
import 'package:quadcraft/features/play/win_sheet.dart';
import 'package:quadcraft/ui/theme.dart';

late MemoryProgressStore store;

Widget host(Widget child) {
  store = MemoryProgressStore();
  return ProviderScope(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      soundBankProvider.overrideWithValue(SoundBank.silent()),
    ],
    child: MaterialApp(theme: AppTheme.build(), home: child),
  );
}

void main() {
  testWidgets('home screen offers the first level', (tester) async {
    await tester.pumpWidget(host(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('QUADCRAFT'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('ALL LEVELS'), findsOneWidget);
    expect(find.text('0 of ${kLevels.length} solved'), findsOneWidget);
  });

  testWidgets('turning the plate solves level 1 and records the clear', (tester) async {
    await tester.pumpWidget(host(const PlayScreen(levelNumber: 1)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('First Turn'), findsOneWidget);
    expect(find.text('TURN'), findsOneWidget);

    await tester.tap(find.text('TURN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(WinSheet), findsOneWidget);
    expect(find.text('Solved'), findsOneWidget);

    final record = store.recordFor(1);
    expect(record, isNotNull);
    expect(record!.bestMoves, 1);
    expect(store.highestUnlocked(kLevels.length), 2);
  });

  testWidgets('tapping blueprints places them and counts moves', (tester) async {
    await tester.pumpWidget(host(const PlayScreen(levelNumber: 3)));
    await tester.pump(const Duration(milliseconds: 100));

    final chips = find.bySemanticsLabel(RegExp('^Blueprint'));
    expect(chips, findsNWidgets(2));

    await tester.tap(chips.first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^Blueprint')).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(WinSheet), findsOneWidget);
  });

  testWidgets('undo walks the board back and reset clears the run', (tester) async {
    await tester.pumpWidget(host(const PlayScreen(levelNumber: 10)));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.bySemanticsLabel(RegExp('^Blueprint')).first);
    await tester.pump(const Duration(milliseconds: 400));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    final provider = playControllerProvider(10);
    expect(container.read(provider).game.moves, 1);
    expect(container.read(provider).game.board.isEmpty, isFalse);

    await tester.tap(find.text('UNDO'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(provider).game.moves, 0);
    expect(container.read(provider).game.board.isEmpty, isTrue);

    await tester.tap(find.bySemanticsLabel(RegExp('^Blueprint')).first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('RESET'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(provider).game.moves, 0);
  });

  testWidgets('a refused drop keeps the move count still', (tester) async {
    // Level 14 fills one quadrant to the cap, so the fifth drop must bounce.
    await tester.pumpWidget(host(const PlayScreen(levelNumber: 14)));
    await tester.pump(const Duration(milliseconds: 100));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    final controller = container.read(playControllerProvider(14).notifier);
    final level = container.read(playControllerProvider(14)).level;
    for (final shape in level.tray) {
      controller.drop(shape);
      await tester.pump(const Duration(milliseconds: 350));
    }
    // Board is solved at four layers; a further drop is ignored outright.
    final movesAtCap = container.read(playControllerProvider(14)).game.moves;
    expect(movesAtCap, 4);
    controller.drop(level.tray.first);
    await tester.pump(const Duration(milliseconds: 350));
    expect(container.read(playControllerProvider(14)).game.moves, movesAtCap);
  });

  testWidgets('level select locks everything past the frontier', (tester) async {
    await tester.pumpWidget(host(const LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Levels'), findsOneWidget);
    expect(find.text('0 / ${kLevels.length}'), findsOneWidget);
    expect(find.text('First Turn'), findsOneWidget);
    // Only the first level is reachable on a fresh save.
    expect(find.text('Locked'), findsWidgets);
  });
}
