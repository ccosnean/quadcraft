import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../core/level/endless/endless_levels.dart';
import '../core/level/level.dart';
import '../core/shape/shape.dart';
import 'level_briefs.dart';

part 'copy.dart';
part 'dive_copy.dart';

enum AppLanguage {
  en('en', 'English'),
  zh('zh', '简体中文'),
  hi('hi', 'हिन्दी'),
  es('es', 'Español'),
  ar('ar', 'العربية'),
  pt('pt', 'Português'),
  fr('fr', 'Français'),
  id('id', 'Bahasa Indonesia'),
  ja('ja', '日本語'),
  de('de', 'Deutsch'),
  ko('ko', '한국어'),
  ru('ru', 'Русский'),
  ro('ro', 'Română');

  const AppLanguage(this.code, this.nativeName);

  final String code;
  final String nativeName;

  Locale get locale => switch (this) {
    AppLanguage.zh => const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    ),
    _ => Locale(code),
  };

  /// Space Grotesk is Latin-only. Inter (and system fallbacks) cover the rest.
  bool get usesDisplayFace => switch (this) {
    en || es || pt || fr || id || de || ro => true,
    _ => false,
  };

  /// Wide tracking is for the machined Latin face. Other scripts sit poorly
  /// with it — and Cyrillic was falling through to a CJK system font.
  bool get usesWideTracking => usesDisplayFace;

  static List<Locale> get supported => [
    for (final language in values) language.locale,
  ];

  static AppLanguage fromCode(String? code) {
    final normalized = switch (code) {
      'in' => 'id',
      'zh' || 'zh_CN' || 'zh_Hans' => 'zh',
      _ => code,
    };
    return switch (normalized) {
      'zh' => AppLanguage.zh,
      'hi' => AppLanguage.hi,
      'es' => AppLanguage.es,
      'ar' => AppLanguage.ar,
      'pt' => AppLanguage.pt,
      'fr' => AppLanguage.fr,
      'id' => AppLanguage.id,
      'ja' => AppLanguage.ja,
      'de' => AppLanguage.de,
      'ko' => AppLanguage.ko,
      'ru' => AppLanguage.ru,
      'ro' => AppLanguage.ro,
      _ => AppLanguage.en,
    };
  }

  /// Device language when it is one we ship; otherwise English.
  static AppLanguage fromPlatform([Locale? locale]) {
    final resolved = locale ?? PlatformDispatcher.instance.locale;
    if (resolved.languageCode == 'zh') return AppLanguage.zh;
    return fromCode(resolved.languageCode);
  }
}

/// Chrome copy. Level names stay in the authored English.
class L10n {
  const L10n(this.language);

  final AppLanguage language;

  UiCopy get _c => switch (language) {
    AppLanguage.en => kCopyEn,
    AppLanguage.zh => kCopyZh,
    AppLanguage.hi => kCopyHi,
    AppLanguage.es => kCopyEs,
    AppLanguage.ar => kCopyAr,
    AppLanguage.pt => kCopyPt,
    AppLanguage.fr => kCopyFr,
    AppLanguage.id => kCopyId,
    AppLanguage.ja => kCopyJa,
    AppLanguage.de => kCopyDe,
    AppLanguage.ko => kCopyKo,
    AppLanguage.ru => kCopyRu,
    AppLanguage.ro => kCopyRo,
  };

  DiveCopy get _d => switch (language) {
    AppLanguage.en => kDiveEn,
    AppLanguage.zh => kDiveZh,
    AppLanguage.hi => kDiveHi,
    AppLanguage.es => kDiveEs,
    AppLanguage.ar => kDiveAr,
    AppLanguage.pt => kDivePt,
    AppLanguage.fr => kDiveFr,
    AppLanguage.id => kDiveId,
    AppLanguage.ja => kDiveJa,
    AppLanguage.de => kDiveDe,
    AppLanguage.ko => kDiveKo,
    AppLanguage.ru => kDiveRu,
    AppLanguage.ro => kDiveRo,
  };

  /// Flavour line under the target. English lives on the level; the others
  /// follow the UI language.
  String levelBrief(int number, String english) {
    if (language == AppLanguage.en) return english;
    return kLevelBriefs[language.code]?[number] ?? english;
  }

  /// Title shown in the play HUD. Campaign levels carry an authored name;
  /// a generated one is named by how deep it sits.
  String levelTitle(Level level) => switch (level.kind) {
    LevelKind.campaign => level.name,
    LevelKind.endless => depthLabel(level.number),
  };

  /// Chapter line above the title.
  String levelSection(Level level) => switch (level.kind) {
    LevelKind.campaign => level.section,
    LevelKind.endless => stratumName(level.stratum),
  };

  /// The line under the target, whichever side of the game it came from.
  String levelLine(Level level) {
    final theme = level.theme;
    if (theme != null) return themeBrief(theme);
    return levelBrief(level.number, level.brief);
  }

  String depthLabel(int n) =>
      _fill(_d.depthLabel, {'n': n.toString().padLeft(2, '0')});

  /// Bands of the dive cycle through six names; past the sixth they take a
  /// numeral, so depth 100 still lands somewhere with a name.
  String stratumName(int stratum) {
    final names = _d.strata;
    final name = names[stratum % names.length];
    final cycle = stratum ~/ names.length;
    return cycle == 0 ? name : '$name ${cycle + 1}';
  }

  String themeBrief(LevelTheme theme) =>
      _d.themes[theme] ?? EndlessLevels.briefFor(theme);

  String get deepest => _d.deepest;
  String get collection => _d.collection;
  String get seedLabel => _d.seedLabel;
  String get seedHint => _d.seedHint;
  String get seedRandom => _d.seedRandom;
  String get seedDefault => _d.seedDefault;
  String get seedBody => _d.seedBody;
  String get diveLocked => _d.diveLocked;
  String get nextDepth => _d.nextDepth;
  String get deepestYet => _d.deepestYet;
  String get newFind => _d.newFind;
  String get freeExplorer => _d.freeExplorer;
  String get freeExplorerNote => _d.freeExplorerNote;
  String get sharedLevel => _d.sharedLevel;
  String get playShared => _d.playShared;
  String get shareCodeHint => _d.shareCodeHint;
  String get shareCodeBad => _d.shareCodeBad;
  String get scanToPlay => _d.scanToPlay;
  String get beatenIt => _d.beatenIt;
  String get sharedNotCounted => _d.sharedNotCounted;
  String get diveThisSeed => _d.diveThisSeed;
  String get diveThisSeedBody => _d.diveThisSeedBody;

  String movesToBeat(int n) => _fill(_d.movesToBeat, {'n': '$n'});

  String get goDeeperHint => _d.goDeeperHint;
  String get useKey => _d.useKey;
  String get outOfKeys => _d.outOfKeys;
  String get openedWithKey => _d.openedWithKey;
  String get keyWon => _d.keyWon;

  String builtCount(int n) => _fill(_d.builtCount, {'n': '$n'});

  String clearedThisRun(int n) => _fill(_d.clearedThisRun, {'n': '$n'});

  String get settings => _c.settings;
  String get tagline => _c.tagline;
  String get start => _c.start;
  String get allLevels => _c.allLevels;
  String get mute => _c.mute;
  String get unmute => _c.unmute;
  String get sound => _c.sound;
  String get soundHint => _c.soundHint;
  String get music => _c.music;
  String get musicHint => _c.musicHint;
  String get confettiLabel => _c.confettiLabel;
  String get confettiHint => _c.confettiHint;
  String get confettiFull => _c.confettiFull;
  String get confettiReduced => _c.confettiReduced;
  String get confettiOff => _c.confettiOff;
  String get targetPreviewLabel => _c.targetPreviewLabel;
  String get targetPreviewHint => _c.targetPreviewHint;
  String get targetPreviewOff => _c.targetPreviewOff;
  String get targetPreviewAuto => _c.targetPreviewAuto;
  String get targetPreviewManual => _c.targetPreviewManual;
  String get dontAutoOpen => _c.dontAutoOpen;
  String get languageLabel => _c.languageLabel;
  String get languageHint => _c.languageHint;
  String get resetGame => _c.resetGame;
  String get resetGameHint => _c.resetGameHint;
  String get progress => _c.progress;
  String get resetStep1Title => _c.resetStep1Title;
  String get resetStep1Body => _c.resetStep1Body;
  String get resetStep2Body => _c.resetStep2Body;
  String get resetStep3Title => _c.resetStep3Title;
  String get resetStep3Body => _c.resetStep3Body;
  String get cancel => _c.cancel;
  String get continueAction => _c.continueAction;
  String get iUnderstand => _c.iUnderstand;
  String get keepProgress => _c.keepProgress;
  String get eraseEverything => _c.eraseEverything;
  String get resetDone => _c.resetDone;
  String get tutorial => _c.tutorial;
  String get skipTutorial => _c.skipTutorial;
  String get replayTutorial => _c.replayTutorial;
  String get tutorialHint => _c.tutorialHint;
  String get copy => _c.copy;
  String get copied => _c.copied;
  String get levels => _c.levels;
  String get locked => _c.locked;
  String get backToLevels => _c.backToLevels;
  String get hint => _c.hint;
  String get hintGone => _c.hintGone;
  String get target => _c.target;
  String get tapToEnlarge => _c.tapToEnlarge;
  String get tapAnywhere => _c.tapAnywhere;
  String get close => _c.close;
  String get closeTargetPreview => _c.closeTargetPreview;
  String get moves => _c.moves;
  String get turn => _c.turn;
  String get cut => _c.cut;
  String get undo => _c.undo;
  String get reset => _c.reset;
  String get hintNone => _c.hintNone;
  String get hintTurn => _c.hintTurn;
  String get hintCut => _c.hintCut;
  String get hintPlace => _c.hintPlace;
  String get blueprints => _c.blueprints;
  String get tapToPlace => _c.tapToPlace;
  String get emptyTray => _c.emptyTray;
  String get paint => _c.paint;
  String get solved => _c.solved;
  String get yourScoreToBeat => _c.yourScoreToBeat;
  String get newBest => _c.newBest;
  String get share => _c.share;
  String get replay => _c.replay;
  String get nextLevel => _c.nextLevel;
  String get shareScore => _c.shareScore;
  String get shareScoreHint => _c.shareScoreHint;
  String get shareFailed => _c.shareFailed;
  String get preparing => _c.preparing;
  String get shareImage => _c.shareImage;

  String continueTutorial(int n) =>
      _fill(_c.continueTutorial, {'n': n.toString().padLeft(2, '0')});

  String solvedCount(int cleared, int total) =>
      _fill(_c.solvedCount, {'cleared': '$cleared', 'total': '$total'});

  String bestMoves(int n) => _fill(_c.bestMoves, {'n': '$n'});

  String yourBest(int n) => _fill(_c.yourBest, {'n': '$n'});

  String tutorialNumber(int n) =>
      _fill(_c.tutorialNumber, {'n': n.toString().padLeft(2, '0')});

  String hintPaint(String color) => _fill(_c.hintPaint, {'color': color});

  String blueprintLabel(String id) => _fill(_c.blueprintLabel, {'id': id});

  String paintLabel(String color) => _fill(_c.paintLabel, {'color': color});

  String personalBest(int n) => _fill(_c.personalBest, {'n': '$n'});

  String sharePromptNew(int moves) =>
      _fill(_c.sharePromptNew, {'moves': '$moves'});

  String sharePromptRepeat(int moves, int best) =>
      _fill(_c.sharePromptRepeat, {'moves': '$moves', 'best': '$best'});

  String thinkYouCanBeat(int moves) =>
      _fill(_c.thinkYouCanBeat, {'moves': '$moves'});

  String shareCaption(int number, String name, int moves) => _fill(
    _c.shareCaption,
    {'number': '$number', 'name': name, 'moves': '$moves'},
  );

  String resetStep2Title(int cleared) {
    final n = '$cleared';
    return switch (language) {
      AppLanguage.en =>
        cleared == 1
            ? 'You will lose 1 solved level'
            : 'You will lose $n solved levels',
      AppLanguage.zh => '将失去 $n 个已过关卡',
      AppLanguage.hi =>
        cleared == 1 ? '1 हल किया स्तर मिट जाएगा' : '$n हल किए स्तर मिट जाएंगे',
      AppLanguage.es =>
        cleared == 1
            ? 'Perderás 1 nivel resuelto'
            : 'Perderás $n niveles resueltos',
      AppLanguage.ar => switch (cleared) {
        1 => 'ستفقد مستوى واحدًا محلولًا',
        2 => 'ستفقد مستويين محلولين',
        _ when cleared >= 3 && cleared <= 10 => 'ستفقد $n مستويات محلولة',
        _ => 'ستفقد $n مستوى محلولًا',
      },
      AppLanguage.pt =>
        cleared == 1
            ? 'Você vai perder 1 nível resolvido'
            : 'Você vai perder $n níveis resolvidos',
      AppLanguage.fr =>
        cleared == 1
            ? 'Vous allez perdre 1 niveau résolu'
            : 'Vous allez perdre $n niveaux résolus',
      AppLanguage.id =>
        cleared == 1
            ? 'Anda akan kehilangan 1 level yang sudah diselesaikan'
            : 'Anda akan kehilangan $n level yang sudah diselesaikan',
      AppLanguage.ja => 'クリア済みのレベルが $n つ消えます',
      AppLanguage.de =>
        cleared == 1
            ? 'Du verlierst 1 gelöstes Level'
            : 'Du verlierst $n gelöste Level',
      AppLanguage.ko => '클리어한 레벨 $n개가 사라집니다',
      AppLanguage.ru => _russianSolvedLevels(cleared),
      AppLanguage.ro =>
        cleared == 1
            ? 'Vei pierde 1 nivel rezolvat'
            : 'Vei pierde $n niveluri rezolvate',
    };
  }

  String colorName(QuadColor color) => switch (color) {
    QuadColor.uncolored => _c.colorBare,
    QuadColor.red => _c.colorRed,
    QuadColor.green => _c.colorGreen,
    QuadColor.blue => _c.colorBlue,
    QuadColor.yellow => _c.colorYellow,
    QuadColor.purple => _c.colorPurple,
    QuadColor.cyan => _c.colorCyan,
    QuadColor.orange => _c.colorOrange,
    QuadColor.magenta => _c.colorMagenta,
  };

  static String _fill(String template, Map<String, String> vars) {
    var out = template;
    for (final entry in vars.entries) {
      out = out.replaceAll('{${entry.key}}', entry.value);
    }
    return out;
  }

  static String _russianSolvedLevels(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) {
      return 'Вы потеряете $n пройденный уровень';
    }
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'Вы потеряете $n пройденных уровня';
    }
    return 'Вы потеряете $n пройденных уровней';
  }
}
