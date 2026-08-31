import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/l10n/l10n.dart';

void main() {
  test(
    'fromPlatform uses supported language codes and falls back to English',
    () {
      expect(AppLanguage.fromPlatform(const Locale('ro')), AppLanguage.ro);
      expect(
        AppLanguage.fromPlatform(const Locale('es', 'MX')),
        AppLanguage.es,
      );
      expect(AppLanguage.fromPlatform(const Locale('de')), AppLanguage.de);
      expect(
        AppLanguage.fromPlatform(const Locale('zh', 'CN')),
        AppLanguage.zh,
      );
      expect(AppLanguage.fromPlatform(const Locale('nl')), AppLanguage.en);
    },
  );

  test('memory store records clears and keeps preferences', () {
    final store = MemoryProgressStore()
      ..muted = true
      ..confetti = ConfettiAmount.off
      ..languageCode = 'ro'
      ..targetPreview = TargetPreviewMode.manual
      ..recordClear(levelNumber: 1, moves: 4)
      ..recordClear(levelNumber: 1, moves: 3);

    expect(store.muted, isTrue);
    expect(store.confetti, ConfettiAmount.off);
    expect(store.languageCode, 'ro');
    expect(store.targetPreview, TargetPreviewMode.manual);
    expect(store.recordFor(1)?.bestMoves, 3);
    expect(store.recordFor(1)?.clears, 2);
    expect(store.highestUnlocked(3), 2);
  });

  test('the dive keeps a seed, a frontier and a collection', () {
    final store = MemoryProgressStore();
    final run = store.diveRun();
    expect(run.depth, 1);
    expect(run.deepest, 0);

    final first = store.recordDiveClear(depth: 1, moves: 6, goalId: 'Cu/-/-/-');
    expect(first.isFirstClear, isTrue);
    expect(first.isNewDepth, isTrue);
    expect(first.isNewDiscovery, isTrue);
    expect(store.diveRun().depth, 2);
    expect(store.diveRun().deepest, 1);

    // Replaying a cleared depth improves the record without moving the
    // frontier or finding the same target twice.
    final again = store.recordDiveClear(depth: 1, moves: 4, goalId: 'Cu/-/-/-');
    expect(again.isFirstClear, isFalse);
    expect(again.isNewBestMoves, isTrue);
    expect(again.isNewDepth, isFalse);
    expect(again.isNewDiscovery, isFalse);
    expect(store.diveRecordFor(1)?.bestMoves, 4);
    expect(store.diveRun().depth, 2);
    expect(store.discoveries().length, 1);
  });

  test('a new run re-seeds the dive but keeps the collection', () {
    final store = MemoryProgressStore();
    final seed = store.diveRun().seed;
    store
      ..recordDiveClear(depth: 1, moves: 5, goalId: 'Cu/-/-/-')
      ..recordDiveClear(depth: 2, moves: 7, goalId: 'Su/Su/-/-');

    final fresh = store.startDive(seed: seed + 1);
    expect(fresh.seed, seed + 1);
    expect(fresh.depth, 1);
    expect(fresh.deepest, 0);
    expect(fresh.runs, 2);
    expect(store.diveRecordFor(1), isNull);
    expect(store.discoveries().length, 2);
  });

  test('a fresh install starts on the shipped seed', () {
    final run = MemoryProgressStore().diveRun();
    // Drawn for this install rather than shared with every other one, and
    // remembered so a borrowed seed can always be handed back.
    expect(run.seed, greaterThan(0));
    expect(run.homeSeed, run.seed);
  });

  test('devUnlockAll persists and resets with everything else', () {
    final store = MemoryProgressStore();
    expect(store.devUnlockAll, isFalse);
    store.devUnlockAll = true;
    expect(store.devUnlockAll, isTrue);
    store.resetAll();
    expect(store.devUnlockAll, isFalse);
  });

  test('resetAll wipes records and restores default settings', () {
    final store = MemoryProgressStore()
      ..muted = true
      ..confetti = ConfettiAmount.reduced
      ..languageCode = 'es'
      ..targetPreview = TargetPreviewMode.off
      ..recordClear(levelNumber: 1, moves: 4)
      ..recordDiveClear(depth: 1, moves: 4, goalId: 'Cu/-/-/-');

    store.resetAll();
    expect(store.recordFor(1), isNull);
    expect(store.diveRecordFor(1), isNull);
    expect(store.discoveries(), isEmpty);
    expect(store.diveRun().deepest, 0);
    expect(store.muted, isFalse);
    expect(store.confetti, ConfettiAmount.full);
    expect(store.targetPreview, TargetPreviewMode.auto);
    expect(store.languageCode, AppLanguage.fromPlatform().code);
  });
}
