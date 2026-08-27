import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(l10n.continueLevel(7), contains('07'), reason: language.code);
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
      for (final color in QuadColor.values) {
        expect(l10n.colorName(color).trim(), isNotEmpty, reason: language.code);
      }
      if (language != AppLanguage.en) {
        expect(l10n.settings, isNot(const L10n(AppLanguage.en).settings));
        expect(l10n.tagline, isNot(const L10n(AppLanguage.en).tagline));
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
}
