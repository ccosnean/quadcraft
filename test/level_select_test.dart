import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/level/endless/endless_levels.dart';
import 'package:quadcraft/core/level/levels.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/levels/level_select_screen.dart';
import 'package:quadcraft/features/play/play_screen.dart';
import 'package:quadcraft/ui/theme.dart';

late MemoryProgressStore store;

Widget host({required bool tutorialDone, int clearedDepths = 0}) {
  store = MemoryProgressStore();
  if (tutorialDone) {
    for (final level in kLevels) {
      store.recordClear(levelNumber: level.number, moves: 4);
    }
  }
  for (var depth = 1; depth <= clearedDepths; depth++) {
    store.recordDiveClear(depth: depth, moves: 9, goalId: 'probe-$depth');
  }
  return ProviderScope(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      soundBankProvider.overrideWithValue(SoundBank.silent()),
    ],
    child: MaterialApp(
      theme: AppTheme.build(),
      home: const LevelSelectScreen(),
    ),
  );
}

/// Whether [label] can be scrolled to in the list. The list is lazy, so a
/// heading far down only exists once it has been scrolled near.
Future<bool> canReach(WidgetTester tester, String label) async {
  final target = find.text(label);
  for (var page = 0; page < 60; page++) {
    if (target.evaluate().isNotEmpty) return true;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump();
  }
  return target.evaluate().isNotEmpty;
}

/// First band of the second chunk — the tell that a new chunk was revealed.
const _secondChunkBand = 'Starfall';

/// Last band of the first chunk.
const _firstChunkLastBand = 'The Deep Loom';

void main() {
  setUp(EndlessLevels.clearCache);

  testWidgets('no generated levels until the tutorial is finished', (
    tester,
  ) async {
    await tester.pumpWidget(host(tutorialDone: false));
    await tester.pump();

    expect(find.text('Tutorial · Turn'), findsOneWidget);
    expect(await canReach(tester, 'The Shallows'), isFalse);
  });

  testWidgets('finishing the tutorial reveals the first chunk in full', (
    tester,
  ) async {
    await tester.pumpWidget(host(tutorialDone: true));
    await tester.pump();

    expect(await canReach(tester, 'The Shallows'), isTrue);
    expect(await canReach(tester, _firstChunkLastBand), isTrue);
  });

  testWidgets('the ladder has no end and needs no unlocking to scroll', (
    tester,
  ) async {
    // There used to be a fifty-card reveal here, and the second band of the
    // second chunk only appeared once all fifty were cleared. The list is
    // endless now: scrolling is not a reward, it is just scrolling.
    await tester.pumpWidget(host(tutorialDone: true));
    await tester.pump();

    expect(await canReach(tester, _firstChunkLastBand), isTrue);
    expect(
      await canReach(tester, _secondChunkBand),
      isTrue,
      reason: 'nothing cleared, and the ladder still goes on',
    );
  });

  testWidgets('a depth past the frontier shows its target rather than hiding '
      'it', (tester) async {
    await tester.pumpWidget(host(tutorialDone: true));
    // The feed builds a few levels per frame, so give it several.
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      find.byIcon(Icons.lock_rounded),
      findsWidgets,
      reason: 'depths past the frontier are still locked',
    );
    expect(
      find.byIcon(Icons.help_outline_rounded),
      findsNothing,
      reason: 'but the dive shows what is coming',
    );
  });

  testWidgets('tapping a locked depth says why instead of opening it', (
    tester,
  ) async {
    await tester.pumpWidget(host(tutorialDone: true));
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Nothing cleared, so the frontier is depth 1 and depth 5 is shut.
    await tester.tap(find.text('05'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(PlayScreen), findsNothing);
  });
}
