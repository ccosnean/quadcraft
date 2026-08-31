import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/level/endless/endless_levels.dart';
import 'package:quadcraft/core/level/levels.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/levels/level_select_screen.dart';
import 'package:quadcraft/features/play/win_sheet.dart';
import 'package:quadcraft/l10n/l10n.dart';
import 'package:quadcraft/ui/theme.dart';

/// A clock the test moves by hand.
class _Clock {
  DateTime now = DateTime(2026, 8, 30, 9);
  DateTime call() => now;
}

late MemoryProgressStore store;

Widget host() {
  store = MemoryProgressStore();
  for (final level in kLevels) {
    store.recordClear(levelNumber: level.number, moves: 4);
  }
  return ProviderScope(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      soundBankProvider.overrideWithValue(SoundBank.silent()),
    ],
    child: MaterialApp(theme: AppTheme.build(), home: const LevelSelectScreen()),
  );
}

void main() {
  setUp(EndlessLevels.clearCache);

  group('the purse', () {
    test('starts full and empties as it is spent', () {
      final store = MemoryProgressStore();
      expect(store.keysToday(), kDailyKeys);

      expect(store.unlockWithKey(9), isTrue);
      expect(store.keysToday(), kDailyKeys - 1);
      expect(store.unlockWithKey(10), isTrue);
      expect(store.unlockWithKey(11), isTrue);

      expect(store.keysToday(), 0);
      expect(
        store.unlockWithKey(12),
        isFalse,
        reason: 'an empty purse opens nothing',
      );
      expect(store.diveRun().keyUnlocked, containsAll([9, 10, 11]));
      expect(store.diveRun().keyUnlocked, isNot(contains(12)));
    });

    test('spending twice on the same depth only costs once', () {
      final store = MemoryProgressStore();
      expect(store.unlockWithKey(9), isTrue);
      expect(store.keysToday(), kDailyKeys - 1);
      expect(store.unlockWithKey(9), isTrue, reason: 'already open');
      expect(store.keysToday(), kDailyKeys - 1, reason: 'and still only one');
    });

    test('refills on a new day, and does not stockpile', () {
      final clock = _Clock();
      final store = MemoryProgressStore(clock: clock.call);
      store.unlockWithKey(9);
      store.unlockWithKey(10);
      expect(store.keysToday(), kDailyKeys - 2);

      // Later the same day changes nothing.
      clock.now = DateTime(2026, 8, 30, 23, 59);
      expect(store.keysToday(), kDailyKeys - 2);

      clock.now = DateTime(2026, 8, 31, 0, 1);
      expect(store.keysToday(), kDailyKeys);

      // Three days pass without a key being spent: still three, not nine.
      clock.now = DateTime(2026, 9, 3, 12);
      expect(
        store.keysToday(),
        kDailyKeys,
        reason: 'unspent keys must not accumulate into a skeleton key',
      );
    });

    test('the refill rule is a pure function of the day', () {
      expect(
        refilledKeys(keys: 1, grantedOn: 20260830, today: 20260830),
        (keys: 1, day: 20260830),
      );
      expect(
        refilledKeys(keys: 1, grantedOn: 20260830, today: 20260831),
        (keys: kDailyKeys, day: 20260831),
      );
      // A save written before keys existed reads zeroes, and zero is never a
      // real day — so it refills rather than starting the player at nothing.
      expect(
        refilledKeys(keys: 0, grantedOn: 0, today: 20260830),
        (keys: kDailyKeys, day: 20260830),
      );
    });

    test('stamps a day the way a player means it', () {
      expect(dayStamp(DateTime(2026, 8, 30, 23, 59)), 20260830);
      expect(dayStamp(DateTime(2026, 8, 31, 0, 0)), 20260831);
    });
  });

  group('winning one', () {
    test('lands on every tenth clear and nowhere else', () {
      final store = MemoryProgressStore();
      final won = <int>[];
      for (var depth = 1; depth <= 35; depth++) {
        final result = store.recordDiveClear(
          depth: depth,
          moves: 9,
          goalId: 'goal-$depth',
        );
        if (result.earnedKey) won.add(depth);
      }
      expect(won, [10, 20, 30]);
    });

    test('a repeat clear wins nothing', () {
      final store = MemoryProgressStore();
      for (var depth = 1; depth <= 10; depth++) {
        store.recordDiveClear(depth: depth, moves: 9, goalId: 'goal-$depth');
      }
      final again = store.recordDiveClear(
        depth: 10,
        moves: 2,
        goalId: 'goal-10',
      );
      expect(again.earnedKey, isFalse, reason: 'the count did not move');
    });

    test('adds to the purse', () {
      final store = MemoryProgressStore();
      expect(store.keysToday(), kDailyKeys);
      for (var depth = 1; depth <= kClearsPerKey; depth++) {
        store.recordDiveClear(depth: depth, moves: 9, goalId: 'goal-$depth');
      }
      expect(store.keysToday(), kDailyKeys + 1);
    });

    test('survives the daily wipe, unlike the grant', () {
      // The interaction that matters: the daily grant is deliberately
      // use-it-or-lose-it, and a key earned over ten levels must not be
      // caught by that rule.
      final clock = _Clock();
      final store = MemoryProgressStore(clock: clock.call);
      for (var depth = 1; depth <= kClearsPerKey * 2; depth++) {
        store.recordDiveClear(depth: depth, moves: 9, goalId: 'goal-$depth');
      }
      expect(store.keysToday(), kDailyKeys + 2);

      clock.now = DateTime(2026, 9, 5, 10);
      expect(
        store.keysToday(),
        kDailyKeys + 2,
        reason: 'earned keys bank; only the daily grant resets',
      );
    });

    test('spends the expiring grant before the banked keys', () {
      final clock = _Clock();
      final store = MemoryProgressStore(clock: clock.call);
      for (var depth = 1; depth <= kClearsPerKey; depth++) {
        store.recordDiveClear(depth: depth, moves: 9, goalId: 'goal-$depth');
      }
      expect(store.keysToday(), kDailyKeys + 1);

      // Spend exactly the daily grant.
      for (var i = 0; i < kDailyKeys; i++) {
        expect(store.unlockWithKey(500 + i), isTrue);
      }
      expect(store.keysToday(), 1, reason: 'the earned one is left');

      clock.now = DateTime(2026, 9, 1, 10);
      expect(
        store.keysToday(),
        kDailyKeys + 1,
        reason: 'a fresh grant on top of the key that was kept back',
      );
    });
  });

  group('the ladder', () {
    test('honours a depth a key opened, and nothing beyond it', () {
      final store = MemoryProgressStore();
      store.unlockWithKey(9);
      final container = ProviderContainer(
        overrides: [progressStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      final dive = container.read(diveProvider);
      expect(dive.isUnlocked(9), isTrue);
      expect(dive.isUnlocked(10), isFalse);
      expect(dive.canUnlockWithKey(10), isTrue);
      expect(
        dive.canUnlockWithKey(9),
        isFalse,
        reason: 'already open, so a key would do nothing',
      );
    });

    test('forgets key unlocks when the seed changes', () {
      final store = MemoryProgressStore();
      store.unlockWithKey(9);
      final container = ProviderContainer(
        overrides: [progressStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      expect(container.read(diveProvider).isUnlocked(9), isTrue);

      container.read(diveProvider.notifier).useSeed(777);
      expect(
        container.read(diveProvider).isUnlocked(9),
        isFalse,
        reason: 'depth 9 is a different puzzle now',
      );
    });
  });

  group('the level list', () {
    testWidgets('shows how many keys are left', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.byIcon(Icons.vpn_key_rounded), findsOneWidget);
      expect(find.text('$kDailyKeys'), findsOneWidget);
    });

    testWidgets('offers a key on a locked depth and spends it', (tester) async {
      await tester.pumpWidget(host());
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      const l10n = L10n(AppLanguage.en);
      await tester.tap(find.text('05'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(l10n.useKey), findsOneWidget);
      await tester.tap(find.text(l10n.useKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(store.diveRun().keyUnlocked, contains(5));
      expect(store.keysToday(), kDailyKeys - 1);
    });

    testWidgets('says so once the purse is empty', (tester) async {
      await tester.pumpWidget(host());
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Drain the purse through the notifier, so the screen sees it happen.
      // Poking the store directly leaves the snapshot holding the old count.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LevelSelectScreen)),
      );
      for (var depth = 50; depth < 50 + kDailyKeys; depth++) {
        container.read(diveProvider.notifier).unlockWithKey(depth);
      }
      await tester.pump();

      const l10n = L10n(AppLanguage.en);
      await tester.tap(find.text('05'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(l10n.outOfKeys), findsOneWidget);
      expect(find.text(l10n.useKey), findsNothing);
    });
  });

  group('the win sheet', () {
    Widget sheet(ClearResult result) => ProviderScope(
      overrides: [
        progressStoreProvider.overrideWithValue(MemoryProgressStore()),
        soundBankProvider.overrideWithValue(SoundBank.silent()),
      ],
      child: MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: WinSheet(
            level: kLevels.first,
            result: result,
            hasNext: true,
          ),
        ),
      ),
    );

    const cleared = ClearResult(
      moves: 9,
      bestMoves: 9,
      isNewBestMoves: true,
      isFirstClear: true,
    );
    const l10n = L10n(AppLanguage.en);

    testWidgets('says so, beside going next and sharing', (tester) async {
      await tester.pumpWidget(
        sheet(
          const ClearResult(
            moves: 9,
            bestMoves: 9,
            isNewBestMoves: true,
            isFirstClear: true,
            earnedKey: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text(l10n.keyWon.toUpperCase()), findsOneWidget);
      expect(find.byIcon(Icons.vpn_key_rounded), findsOneWidget);
      // The badge sits on the same sheet as the buttons, not a screen of
      // its own — that is the whole point of putting it here.
      expect(find.text(l10n.share.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.replay.toUpperCase()), findsOneWidget);
    });

    testWidgets('and stays quiet on the other nine', (tester) async {
      await tester.pumpWidget(sheet(cleared));
      await tester.pump();

      expect(find.text(l10n.keyWon.toUpperCase()), findsNothing);
      expect(find.byIcon(Icons.vpn_key_rounded), findsNothing);
    });
  });
}
