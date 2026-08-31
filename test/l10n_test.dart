import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/core/level/endless/endless_levels.dart';
import 'package:quadcraft/core/level/level.dart';
import 'package:quadcraft/core/level/levels.dart';
import 'package:quadcraft/core/shape/shape.dart';
import 'package:quadcraft/l10n/l10n.dart';
import 'package:quadcraft/l10n/level_briefs.dart';

void main() {
  test('fromCode and fromPlatform cover every shipped language', () {
    for (final language in AppLanguage.values) {
      expect(AppLanguage.fromCode(language.code), language);
    }
    expect(AppLanguage.fromCode('in'), AppLanguage.id);
    expect(AppLanguage.fromPlatform(const Locale('ja')), AppLanguage.ja);
    expect(AppLanguage.fromPlatform(const Locale('ar', 'EG')), AppLanguage.ar);
    expect(AppLanguage.fromPlatform(const Locale('pt', 'BR')), AppLanguage.pt);
    expect(
      AppLanguage.fromPlatform(const Locale.fromSubtags(languageCode: 'zh')),
      AppLanguage.zh,
    );
    expect(AppLanguage.ru.usesDisplayFace, isFalse);
    expect(AppLanguage.ru.usesWideTracking, isFalse);
    expect(AppLanguage.en.usesDisplayFace, isTrue);
    expect(AppLanguage.zh.usesDisplayFace, isFalse);
  });

  test('every language fills chrome templates and keeps a local tagline', () {
    for (final language in AppLanguage.values) {
      final l10n = L10n(language);
      expect(l10n.settings, isNotEmpty, reason: language.code);
      expect(l10n.tagline, isNotEmpty, reason: language.code);
      expect(l10n.continueTutorial(7), contains('07'), reason: language.code);
      expect(l10n.solvedCount(3, kLevels.length), contains('3'));
      expect(
        l10n.solvedCount(3, kLevels.length),
        contains('${kLevels.length}'),
      );
      expect(l10n.shareCaption(4, 'First Turn', 6), contains('4'));
      expect(l10n.shareCaption(4, 'First Turn', 6), contains('First Turn'));
      expect(l10n.shareCaption(4, 'First Turn', 6), contains('6'));
      expect(
        l10n.hintPaint(l10n.colorName(QuadColor.red)),
        isNot(contains('{color}')),
      );
      expect(l10n.thinkYouCanBeat(12), isNot(contains('{moves}')));
      expect(l10n.sharedLevel, isNotEmpty, reason: language.code);
      expect(l10n.music, isNotEmpty, reason: language.code);
      expect(l10n.musicHint, isNotEmpty, reason: language.code);
      expect(l10n.tutorial, isNotEmpty, reason: language.code);
      expect(l10n.replayTutorial, isNotEmpty, reason: language.code);
      expect(l10n.tutorialHint, isNotEmpty, reason: language.code);
      expect(l10n.copy, isNotEmpty, reason: language.code);
      expect(l10n.copied, isNotEmpty, reason: language.code);
      expect(l10n.tutorialNumber(3), contains('03'), reason: language.code);
      expect(l10n.playShared, isNotEmpty, reason: language.code);
      expect(l10n.shareCodeHint, isNotEmpty, reason: language.code);
      expect(l10n.shareCodeBad, isNotEmpty, reason: language.code);
      expect(l10n.scanToPlay, isNotEmpty, reason: language.code);
      expect(l10n.beatenIt, isNotEmpty, reason: language.code);
      expect(l10n.sharedNotCounted, isNotEmpty, reason: language.code);
      expect(l10n.diveThisSeed, isNotEmpty, reason: language.code);
      expect(l10n.diveThisSeedBody, isNotEmpty, reason: language.code);
      expect(l10n.movesToBeat(14), contains('14'), reason: language.code);
      expect(
        l10n.movesToBeat(14),
        isNot(contains('{n}')),
        reason: language.code,
      );
      for (final color in QuadColor.values) {
        expect(l10n.colorName(color).trim(), isNotEmpty, reason: language.code);
      }
      if (language != AppLanguage.en) {
        expect(l10n.settings, isNot(const L10n(AppLanguage.en).settings));
        expect(l10n.tagline, isNot(const L10n(AppLanguage.en).tagline));
        expect(
          l10n.playShared,
          isNot(const L10n(AppLanguage.en).playShared),
          reason: language.code,
        );
        expect(
          l10n.musicHint,
          isNot(const L10n(AppLanguage.en).musicHint),
          reason: language.code,
        );
      }
    }
  });

  test('reset copy picks a plural that matches the count', () {
    expect(
      const L10n(AppLanguage.en).resetStep2Title(1),
      contains('1 solved level'),
    );
    expect(
      const L10n(AppLanguage.en).resetStep2Title(4),
      contains('4 solved levels'),
    );
    expect(const L10n(AppLanguage.ru).resetStep2Title(1), contains('уровень'));
    expect(const L10n(AppLanguage.ru).resetStep2Title(3), contains('уровня'));
    expect(const L10n(AppLanguage.ru).resetStep2Title(5), contains('уровней'));
    expect(const L10n(AppLanguage.ar).resetStep2Title(1), contains('واحد'));
    expect(const L10n(AppLanguage.ar).resetStep2Title(2), contains('مستويين'));
  });

  test('level briefs exist for every non-English language', () {
    final numbers = {for (final level in kLevels) level.number};
    for (final language in AppLanguage.values.where(
      (l) => l != AppLanguage.en,
    )) {
      expect(kLevelBriefs[language.code]!.keys.toSet(), numbers);
      expect(
        const L10n(AppLanguage.en).levelBrief(1, kLevels.first.brief),
        kLevels.first.brief,
      );
      expect(
        L10n(language).levelBrief(1, kLevels.first.brief),
        isNot(kLevels.first.brief),
      );
    }
  });

  test('every language names the dive, its bands and every target line', () {
    for (final language in AppLanguage.values) {
      final l10n = L10n(language);
      final code = language.code;
      expect(l10n.collection, isNotEmpty, reason: code);
      expect(l10n.seedBody, isNotEmpty, reason: code);
      expect(l10n.seedDefault, isNotEmpty, reason: code);
      expect(l10n.seedRandom, isNotEmpty, reason: code);
      expect(l10n.diveLocked, isNotEmpty, reason: code);
      expect(l10n.depthLabel(7), contains('07'), reason: code);
      expect(l10n.builtCount(4), contains('4'), reason: code);
      expect(l10n.clearedThisRun(9), contains('9'), reason: code);
      expect(l10n.depthLabel(7), isNot(contains('{n}')), reason: code);

      // Six bands, then the same names with a numeral, forever.
      expect(l10n.stratumName(0), isNotEmpty, reason: code);
      final names = {for (var i = 0; i < 6; i++) l10n.stratumName(i)};
      expect(names.length, 6, reason: code);
      expect(l10n.stratumName(6), contains(l10n.stratumName(0)), reason: code);
      expect(l10n.stratumName(6), contains('2'), reason: code);

      for (final theme in LevelTheme.values) {
        expect(l10n.themeBrief(theme), isNotEmpty, reason: '$code $theme');
        if (language != AppLanguage.en) {
          expect(
            l10n.themeBrief(theme),
            isNot(EndlessLevels.briefFor(theme)),
            reason: '$code $theme is still the English line',
          );
        }
      }
    }
  });

  test('a generated level titles and describes itself in every language', () {
    final level = EndlessLevels.levelAt(seed: 4242, depth: 13);
    for (final language in AppLanguage.values) {
      final l10n = L10n(language);
      expect(l10n.levelTitle(level), contains('13'), reason: language.code);
      expect(
        l10n.levelSection(level),
        l10n.stratumName(level.stratum),
        reason: language.code,
      );
      expect(
        l10n.levelLine(level),
        l10n.themeBrief(level.theme!),
        reason: language.code,
      );
    }
    // Campaign levels keep their authored copy.
    expect(
      const L10n(AppLanguage.en).levelTitle(kLevels.first),
      kLevels.first.name,
    );
  });
}
