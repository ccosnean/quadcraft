import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/level/endless/endless_levels.dart';
import 'package:quadcraft/core/level/level.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/play/play_screen.dart';
import 'package:quadcraft/l10n/l10n.dart';
import 'package:quadcraft/ui/theme.dart';
import 'package:quadcraft/ui/widgets.dart';

late MemoryProgressStore store;

Widget host(Widget child, {void Function(MemoryProgressStore)? seed}) {
  store = MemoryProgressStore();
  seed?.call(store);
  return ProviderScope(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      soundBankProvider.overrideWithValue(SoundBank.silent()),
    ],
    child: MaterialApp(theme: AppTheme.build(), home: child),
  );
}

/// Clears the target intro so the header is on screen.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  final intro = find.byKey(const Key('target-intro'));
  if (intro.evaluate().isNotEmpty) {
    await tester.tap(intro);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  setUp(EndlessLevels.clearCache);

  const l10n = L10n(AppLanguage.en);

  testWidgets('a level never cleared shows nothing to beat', (tester) async {
    await tester.pumpWidget(host(const PlayScreen(level: LevelRef.campaign(1))));
    await settle(tester);

    expect(find.textContaining(l10n.yourBest(0).split(':').first), findsNothing);
  });

  testWidgets('replaying a cleared campaign level shows the record', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const PlayScreen(level: LevelRef.campaign(1)),
        seed: (store) => store.recordClear(levelNumber: 1, moves: 12),
      ),
    );
    await settle(tester);

    expect(find.text(l10n.yourBest(12)), findsOneWidget);
  });

  testWidgets('and so does a depth already dived', (tester) async {
    await tester.pumpWidget(
      host(
        const PlayScreen(level: LevelRef.endless(seed: 0, number: 3)),
        seed: (store) => store.recordDiveClear(
          depth: 3,
          moves: 17,
          goalId: 'goal-3',
        ),
      ),
    );
    await settle(tester);

    expect(find.text(l10n.yourBest(17)), findsOneWidget);
  });

  testWidgets('a challenge shows their score, never yours', (tester) async {
    // The same depth, cleared before, opened from somebody's code. Their
    // number is the only one that means anything here — a record of yours on
    // your own ladder is a different puzzle wearing the same depth.
    await tester.pumpWidget(
      host(
        const PlayScreen(
          level: LevelRef.endless(seed: 0, number: 3, isChallenge: true),
          movesToBeat: 8,
        ),
        seed: (store) => store.recordDiveClear(
          depth: 3,
          moves: 17,
          goalId: 'goal-3',
        ),
      ),
    );
    await settle(tester);

    expect(find.text(l10n.movesToBeat(8)), findsOneWidget);
    expect(find.text(l10n.yourBest(17)), findsNothing);
  });

  testWidgets('the record only counts while you are under it', (tester) async {
    await tester.pumpWidget(
      host(
        const PlayScreen(level: LevelRef.campaign(1)),
        seed: (store) => store.recordClear(levelNumber: 1, moves: 12),
      ),
    );
    await settle(tester);

    // Freshly opened, no moves spent: the readout is ahead of the record.
    final readout = tester.widget<Readout>(
      find.ancestor(
        of: find.text(l10n.yourBest(12)),
        matching: find.byType(Readout),
      ),
    );
    expect(readout.highlight, isTrue);
  });
}
