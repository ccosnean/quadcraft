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

  test('resetAll wipes records and restores default settings', () {
    final store = MemoryProgressStore()
      ..muted = true
      ..confetti = ConfettiAmount.reduced
      ..languageCode = 'es'
      ..targetPreview = TargetPreviewMode.off
      ..recordClear(levelNumber: 1, moves: 4);

    store.resetAll();
    expect(store.recordFor(1), isNull);
    expect(store.muted, isFalse);
    expect(store.confetti, ConfettiAmount.full);
    expect(store.targetPreview, TargetPreviewMode.auto);
    expect(store.languageCode, AppLanguage.fromPlatform().code);
  });
}
