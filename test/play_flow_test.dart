import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/core/level/level.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/level/levels.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/home/home_screen.dart';
import 'package:quadcraft/features/levels/level_select_screen.dart';
import 'package:quadcraft/features/play/play_controller.dart';
import 'package:quadcraft/features/play/play_screen.dart';
import 'package:quadcraft/features/play/win_sheet.dart';
import 'package:quadcraft/features/settings/settings_screen.dart';
import 'package:quadcraft/l10n/l10n.dart';
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

Future<void> dismissTargetIntro(WidgetTester tester) async {
  expect(find.byKey(const Key('target-intro')), findsOneWidget);
  await tester.tap(find.byKey(const Key('target-intro')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byKey(const Key('target-intro')), findsNothing);
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

  testWidgets('opening a level shows the target then heroes it into the HUD', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const PlayScreen(level: LevelRef.campaign(1))),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('target-intro')), findsOneWidget);
    expect(find.text('Tap anywhere'), findsOneWidget);
    expect(find.text("Don't auto-open"), findsOneWidget);
    expect(find.text('First Turn'), findsWidgets);

    await dismissTargetIntro(tester);

    expect(find.text('First Turn'), findsOneWidget);

    await tester.tap(find.byTooltip('Tap to enlarge'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Close'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Close'), findsNothing);
  });

  testWidgets('turning the plate solves level 1 and records the clear', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const PlayScreen(level: LevelRef.campaign(1))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await dismissTargetIntro(tester);

    expect(find.text('First Turn'), findsOneWidget);
    expect(find.text('TURN'), findsOneWidget);

    await tester.tap(find.text('TURN'));
    await tester.pump();
    // Win celebration + sheet open; avoid pumpAndSettle (ambient BG ticker never idles).
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byType(WinSheet), findsOneWidget);
    expect(find.text('Solved'), findsOneWidget);

    final record = store.recordFor(1);
    expect(record, isNotNull);
    expect(record!.bestMoves, 1);
    expect(store.highestUnlocked(kLevels.length), 2);
  });

  testWidgets('tapping blueprints places them and counts moves', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const PlayScreen(level: LevelRef.campaign(5))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await dismissTargetIntro(tester);

    final chips = find.bySemanticsLabel(RegExp('^Blueprint'));
    expect(chips, findsNWidgets(2));

    await tester.tap(chips.first);
    await tester.pump(); // mount flight overlay
    await tester.pump(
      const Duration(milliseconds: 500),
    ); // finish flight + place
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^Blueprint')).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Win celebration + sheet open; avoid pumpAndSettle (ambient BG ticker never idles).
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byType(WinSheet), findsOneWidget);
  });

  testWidgets('undo walks the board back and reset clears the run', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const PlayScreen(level: LevelRef.campaign(10))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await dismissTargetIntro(tester);

    await tester.tap(find.bySemanticsLabel(RegExp('^Blueprint')).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    final provider = playControllerProvider(LevelRef.campaign(10));
    expect(container.read(provider).game.moves, 1);
    expect(container.read(provider).game.board.isEmpty, isFalse);

    await tester.tap(find.text('UNDO'));
    await tester.pump(const Duration(milliseconds: 550));
    expect(container.read(provider).game.moves, 0);
    expect(container.read(provider).game.board.isEmpty, isTrue);

    await tester.tap(find.bySemanticsLabel(RegExp('^Blueprint')).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('RESET'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(provider).game.moves, 0);
  });

  testWidgets('a refused drop keeps the move count still', (tester) async {
    // Layer Cap fills one quadrant to the limit, so a fifth drop must bounce.
    await tester.pumpWidget(
      host(const PlayScreen(level: LevelRef.campaign(12))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await dismissTargetIntro(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    final controller = container.read(
      playControllerProvider(LevelRef.campaign(12)).notifier,
    );
    final level = container
        .read(playControllerProvider(LevelRef.campaign(12)))
        .level;
    for (final shape in level.tray) {
      controller.drop(shape);
      await tester.pump(const Duration(milliseconds: 350));
    }
    // Board is solved at four layers; a further drop is ignored outright.
    final movesAtCap = container
        .read(playControllerProvider(LevelRef.campaign(12)))
        .game
        .moves;
    expect(movesAtCap, 4);
    controller.drop(level.tray.first);
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      container.read(playControllerProvider(LevelRef.campaign(12))).game.moves,
      movesAtCap,
    );
  });

  testWidgets('level select locks everything past the frontier', (
    tester,
  ) async {
    await tester.pumpWidget(host(const LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    // Until the lessons are done there is no ladder, so the list is the
    // lessons and says so.
    expect(find.text('Tutorial'), findsOneWidget);
    expect(find.text('0 / ${kLevels.length}'), findsOneWidget);
    expect(find.text('First Turn'), findsOneWidget);
    // Only the first level is reachable on a fresh save.
    expect(find.text('Locked'), findsWidgets);
  });

  testWidgets('home keeps mute and play screen does not', (tester) async {
    await tester.pumpWidget(host(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

    await tester.tap(find.text('START'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PlayScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PlayScreen),
        matching: find.byIcon(Icons.volume_up_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(PlayScreen),
        matching: find.byIcon(Icons.volume_off_rounded),
      ),
      findsNothing,
    );
  });

  testWidgets('settings can switch language and confetti', (tester) async {
    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Settings'), findsOneWidget);
    expect(store.confetti, ConfettiAmount.full);

    await tester.tap(find.byKey(const Key('confetti-reduced')));
    await tester.pump();
    expect(store.confetti, ConfettiAmount.reduced);

    await tester.tap(find.byKey(const Key('confetti-off')));
    await tester.pump();
    expect(store.confetti, ConfettiAmount.off);

    await tester.ensureVisible(find.byKey(const Key('target-preview-manual')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('target-preview-manual')));
    await tester.pump();
    expect(store.targetPreview, TargetPreviewMode.manual);

    await tester.ensureVisible(find.text('Română'));
    await tester.pump();
    await tester.tap(find.text('Română'));
    await tester.pump();
    expect(store.languageCode, 'ro');
    expect(find.text('Setări'), findsOneWidget);
  });

  testWidgets('reset aborts unless all three checks pass', (tester) async {
    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    container
        .read(progressProvider.notifier)
        .recordClear(levelNumber: 1, moves: 3);
    container.read(mutedProvider.notifier).toggle();
    container.read(languageProvider.notifier).set(AppLanguage.en);
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('reset-game')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reset-game')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reset-step-confirm')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reset-step-abort')));
    await tester.pump();
    expect(store.recordFor(1), isNotNull);

    await tester.ensureVisible(find.byKey(const Key('reset-game')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reset-game')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reset-step-confirm')));
    await tester.pump();
    // Step 2 confirm stays disabled until the checkbox is ticked.
    await tester.tap(find.byKey(const Key('reset-step-confirm')));
    await tester.pump();
    expect(find.byKey(const Key('reset-understand')), findsOneWidget);
    expect(store.recordFor(1), isNotNull);

    await tester.tap(find.byKey(const Key('reset-understand')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reset-step-confirm')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reset-step-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.recordFor(1), isNull);
    expect(store.highestUnlocked(kLevels.length), 1);
    expect(store.muted, isFalse);
    expect(store.confetti, ConfettiAmount.full);
    expect(store.targetPreview, TargetPreviewMode.auto);
    expect(store.languageCode, AppLanguage.fromPlatform().code);
  });

  testWidgets('hint is capped and adds a move', (tester) async {
    await tester.pumpWidget(
      host(const PlayScreen(level: LevelRef.campaign(1))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await dismissTargetIntro(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    final provider = playControllerProvider(LevelRef.campaign(1));

    for (var i = 0; i < kMaxHintsPerLevel; i++) {
      await tester.tap(find.byKey(const Key('hint')));
      await tester.pump();
    }
    expect(container.read(provider).hintsUsed, kMaxHintsPerLevel);
    expect(container.read(provider).scoredMoves, kMaxHintsPerLevel);
    expect(container.read(provider).game.moves, 0);
    expect(find.text('Turn the plate a quarter clockwise.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hint')));
    await tester.pump();
    expect(container.read(provider).hintsUsed, kMaxHintsPerLevel);

    await tester.tap(find.text('TURN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byType(WinSheet), findsOneWidget);
    expect(store.recordFor(1)!.bestMoves, kMaxHintsPerLevel + 1);
  });
}
