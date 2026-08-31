import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/level/level_catalog.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/home/home_screen.dart';
import 'package:quadcraft/ui/theme.dart';

void main() {
  late MemoryProgressStore store;

  Widget host({required bool tutorialDone}) {
    store = MemoryProgressStore();
    if (tutorialDone) {
      for (var level = 1; level <= kTutorialLevelCount; level++) {
        store.recordClear(levelNumber: level, moves: 3);
      }
    }
    return ProviderScope(
      overrides: [
        progressStoreProvider.overrideWithValue(store),
        soundBankProvider.overrideWithValue(SoundBank.silent()),
      ],
      child: MaterialApp(theme: AppTheme.build(), home: const HomeScreen()),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(host(tutorialDone: true));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('home-seed-card')));
    await settle(tester);
  }

  testWidgets('every install is given its own seed', (tester) async {
    // The point of a per-device seed is that trading one is a decision. If
    // everybody started on the same number there would be nothing to trade.
    final seeds = {
      for (var i = 0; i < 5; i++) MemoryProgressStore().diveRun().seed,
    };
    expect(seeds.length, greaterThan(1));

    final run = MemoryProgressStore().diveRun();
    expect(run.homeSeed, run.seed);
    expect(run.seed, greaterThan(0));
  });

  testWidgets('the seed is on the front page, not buried in settings', (
    tester,
  ) async {
    await tester.pumpWidget(host(tutorialDone: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('home-seed-card')), findsOneWidget);
    expect(find.text('${store.diveRun().seed}'), findsOneWidget);
  });

  testWidgets('it is on show from the very first launch', (tester) async {
    // A number you have never seen is not one you would think to trade, so
    // the card does not wait for the ladder to open.
    await tester.pumpWidget(host(tutorialDone: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('home-seed-card')), findsOneWidget);
    expect(find.text('${store.diveRun().seed}'), findsOneWidget);
  });

  testWidgets('a typed seed regrows the ladder and can be handed back', (
    tester,
  ) async {
    await openSheet(tester);
    final home = store.diveRun().homeSeed;

    // Nothing to go back to while you are already home.
    final resetBefore = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('seed-default')),
        matching: find.byType(InkWell),
      ),
    );
    expect(resetBefore.onTap, isNull);

    store.recordDiveClear(depth: 1, moves: 6, goalId: 'Cu/-/-/-');
    await tester.enterText(find.byKey(const Key('seed-field')), '13579');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    expect(store.diveRun().seed, 13579);
    expect(store.diveRun().depth, 1);
    // Scores were against puzzles that no longer exist.
    expect(store.diveRecordFor(1), isNull);
    // The collection outlives the seed.
    expect(store.discoveries(), hasLength(1));
    // Home is still home, however far you wander.
    expect(store.diveRun().homeSeed, home);

    await tester.tap(find.byKey(const Key('seed-default')));
    await settle(tester);
    expect(store.diveRun().seed, home);
  });

  testWidgets('the seed can be copied to hand to somebody', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await openSheet(tester);
    await tester.tap(find.byKey(const Key('seed-copy')));
    await settle(tester);

    expect(copied, ['${store.diveRun().seed}']);
  });
}
