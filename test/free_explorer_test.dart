import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/level/endless/endless_levels.dart';
import 'package:quadcraft/core/level/levels.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/levels/level_select_screen.dart';
import 'package:quadcraft/l10n/l10n.dart';
import 'package:quadcraft/ui/theme.dart';

late MemoryProgressStore store;

/// Clears [count] depths the long way, in order, and returns the last result.
ClearResult clearDepths(MemoryProgressStore store, int count) {
  late ClearResult last;
  for (var depth = 1; depth <= count; depth++) {
    last = store.recordDiveClear(depth: depth, moves: 9, goalId: 'goal-$depth');
  }
  return last;
}

Widget host({required int clears}) {
  store = MemoryProgressStore();
  for (final level in kLevels) {
    store.recordClear(levelNumber: level.number, moves: 4);
  }
  clearDepths(store, clears);
  return ProviderScope(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      soundBankProvider.overrideWithValue(SoundBank.silent()),
    ],
    child: MaterialApp(theme: AppTheme.build(), home: const LevelSelectScreen()),
  );
}

DiveSnapshot snapshotFor(int clears) {
  final store = MemoryProgressStore();
  clearDepths(store, clears);
  final container = ProviderContainer(
    overrides: [progressStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container.read(diveProvider);
}

void main() {
  setUp(EndlessLevels.clearCache);

  group('the ladder', () {
    test('holds you to one depth at a time until the hundredth clear', () {
      final short = snapshotFor(kFreeExplorerClears - 1);
      expect(short.freeExplorer, isFalse);
      expect(short.clearsToFreeExplorer, 1);
      // The frontier is the next depth, and nothing past it opens.
      expect(short.isUnlocked(short.depth), isTrue);
      expect(short.isUnlocked(short.depth + 1), isFalse);
      expect(short.isUnlocked(5000), isFalse);
    });

    test('opens completely on the hundredth', () {
      final free = snapshotFor(kFreeExplorerClears);
      expect(free.freeExplorer, isTrue);
      expect(free.clearsToFreeExplorer, 0);
      expect(free.isUnlocked(1), isTrue);
      expect(free.isUnlocked(5000), isTrue);
      expect(
        free.isUnlocked(free.depth + 900),
        isTrue,
        reason: 'past the frontier is the whole point',
      );
    });

    test('is never taken away again', () {
      final store = MemoryProgressStore();
      clearDepths(store, kFreeExplorerClears);
      // Re-clearing an old depth is not a first clear, so the count holds.
      store.recordDiveClear(depth: 3, moves: 2, goalId: 'goal-3');
      expect(store.diveRun().clears, greaterThanOrEqualTo(kFreeExplorerClears));
    });
  });

  group('the moment it lands', () {
    test('is called out on exactly one clear', () {
      final store = MemoryProgressStore();
      var announcements = 0;
      for (var depth = 1; depth <= kFreeExplorerClears + 20; depth++) {
        final result = store.recordDiveClear(
          depth: depth,
          moves: 9,
          goalId: 'goal-$depth',
        );
        if (result.becameFreeExplorer) {
          announcements++;
          expect(depth, kFreeExplorerClears, reason: 'on the hundredth');
        }
      }
      expect(announcements, 1);
    });

    test('a repeat clear does not announce it', () {
      final store = MemoryProgressStore();
      clearDepths(store, kFreeExplorerClears);
      final again = store.recordDiveClear(
        depth: 42,
        moves: 3,
        goalId: 'goal-42',
      );
      expect(again.becameFreeExplorer, isFalse);
    });
  });

  testWidgets('the list says so, and stops locking anything', (tester) async {
    await tester.pumpWidget(host(clears: kFreeExplorerClears));
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    const l10n = L10n(AppLanguage.en);
    expect(find.text(l10n.freeExplorer), findsOneWidget);
    expect(find.text(l10n.freeExplorerNote), findsOneWidget);
    expect(
      find.byIcon(Icons.lock_rounded),
      findsNothing,
      reason: 'nothing is locked once the dive is open',
    );
  });

  testWidgets('and does not say so before it is earned', (tester) async {
    await tester.pumpWidget(host(clears: kFreeExplorerClears - 1));
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    const l10n = L10n(AppLanguage.en);
    expect(find.text(l10n.freeExplorer), findsNothing);
    // No lock assertion here: with 99 clears the frontier is depth 100, so
    // everything at the top of the list is legitimately open. That the ladder
    // still bites is asserted on the snapshot, where it can be seen at depth.
    expect(store.diveRun().clears, kFreeExplorerClears - 1);
  });
}
