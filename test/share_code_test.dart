import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/core/level/level.dart';
import 'package:quadcraft/core/level/level_catalog.dart';
import 'package:quadcraft/core/share/share_code.dart';
import 'package:quadcraft/features/play/shared_level_sheet.dart';

void main() {
  group('encoding', () {
    test('a depth is its seed, its number and the score to beat', () {
      final ref = LevelRef.endless(seed: 240816, number: 12);
      expect(ShareCode.encode(ref), '240816-12');
      expect(ShareCode.encode(ref, moves: 14), '240816-12-14');
    });

    test('a campaign level carries no seed', () {
      expect(ShareCode.encode(const LevelRef.campaign(7)), 'L7');
      expect(ShareCode.encode(const LevelRef.campaign(7), moves: 9), 'L7-9');
    });

    test('the challenge flag never reaches the code', () {
      final own = LevelRef.endless(seed: 5, number: 2);
      expect(ShareCode.encode(own.asChallenge()), ShareCode.encode(own));
    });

    test('with no host, the QR carries the code itself', () {
      // Guards the shipped default: a card minted today must not point at a
      // domain nobody owns, because the image outlives the decision.
      final ref = LevelRef.endless(seed: 240816, number: 12);
      expect(kShareHost, isNull);
      expect(ShareCode.link(ref, moves: 14), isNull);
      expect(ShareCode.payload(ref, moves: 14), '240816-12-14');
    });
  });

  group('parsing', () {
    test('round-trips everything it writes', () {
      final refs = [
        LevelRef.endless(seed: 1, number: 1),
        LevelRef.endless(seed: 240816, number: 12),
        LevelRef.endless(seed: 0xFFFFFFFF, number: 999999),
        const LevelRef.campaign(1),
        LevelRef.campaign(kTutorialLevelCount),
      ];
      for (final ref in refs) {
        for (final moves in [null, 1, 14, 999999]) {
          final shared = ShareCode.parse(ShareCode.encode(ref, moves: moves));
          expect(shared, isNotNull, reason: '$ref / $moves');
          expect(shared!.ref.kind, ref.kind);
          expect(shared.ref.number, ref.number);
          expect(shared.ref.seed, ref.seed);
          expect(shared.movesToBeat, moves);
        }
      }
    });

    test('what comes back is always somebody else\'s level', () {
      expect(ShareCode.parse('240816-12')!.ref.isChallenge, isTrue);
      expect(ShareCode.parse('L3')!.ref.isChallenge, isTrue);
    });

    test('reads a code however it was pasted', () {
      final expected = ShareCode.parse('240816-12-14');
      for (final input in [
        '  240816-12-14  ',
        'QC-240816-12-14',
        'QC 240816-12-14',
        'quadcraft: 240816-12-14',
        '240816–12–14',
        '240816 - 12 - 14',
        '- 240816-12-14',
      ]) {
        expect(ShareCode.parse(input), expected, reason: input);
      }
    });

    test('reads a campaign code written either way', () {
      expect(ShareCode.parse('l7-9'), ShareCode.parse('L-7-9'));
      expect(ShareCode.parse('L7')!.ref.number, 7);
    });

    test('reads links, whatever shape they arrive in', () {
      final expected = ShareCode.parse('240816-12-14');
      for (final input in [
        'https://quadcraft.example/d/240816/12?m=14',
        'https://quadcraft.example/play/d/240816/12?m=14',
        'https://quadcraft.example/?s=240816&d=12&m=14',
        'quadcraft://d/240816/12?m=14',
        'https://quadcraft.example/240816-12-14',
      ]) {
        expect(ShareCode.parse(input), expected, reason: input);
      }
      expect(
        ShareCode.parse('https://quadcraft.example/l/7?m=9'),
        ShareCode.parse('L7-9'),
      );
    });

    test('a link without a score still names the level', () {
      final shared = ShareCode.parse('https://quadcraft.example/d/9/4');
      expect(shared!.ref, LevelRef.endless(seed: 9, number: 4).asChallenge());
      expect(shared.movesToBeat, isNull);
    });

    test('refuses anything it cannot read exactly', () {
      for (final input in [
        '',
        '   ',
        'hello',
        '240816',
        '0-5',
        '240816-0',
        '240816-12-0',
        '240816-12-14-3',
        '240816-twelve',
        '2.4-12',
        '+240816-12',
        '99999999999-12',
        'L0',
        'L',
        'https://quadcraft.example/',
        'https://quadcraft.example/d/240816',
      ]) {
        expect(ShareCode.parse(input), isNull, reason: '"$input"');
      }
    });

    test('a campaign level nobody has is a dead code', () {
      expect(ShareCode.parse('L${kTutorialLevelCount + 1}'), isNull);
      expect(ShareCode.parse('L$kTutorialLevelCount'), isNotNull);
    });
  });

  group('whose level it is', () {
    SharedLevel shared(int seed, int depth) => ShareCode.parse('$seed-$depth')!;

    test('a depth you have opened on your own seed is your own level', () {
      final ref = resolveSharedRef(
        shared(240816, 5),
        diveSeed: 240816,
        diveDepth: 9,
        isCampaignUnlocked: false,
      );
      expect(ref.isChallenge, isFalse);
      expect(ref.seed, 240816);
      expect(ref.number, 5);
    });

    test('the frontier itself counts as your own', () {
      final ref = resolveSharedRef(
        shared(240816, 9),
        diveSeed: 240816,
        diveDepth: 9,
        isCampaignUnlocked: false,
      );
      expect(ref.isChallenge, isFalse);
    });

    test('a code can never be used to skip ahead and bank a score', () {
      final ref = resolveSharedRef(
        shared(240816, 400),
        diveSeed: 240816,
        diveDepth: 9,
        isCampaignUnlocked: false,
      );
      expect(ref.isChallenge, isTrue);
    });

    test('another seed is always somebody else\'s', () {
      final ref = resolveSharedRef(
        shared(999, 2),
        diveSeed: 240816,
        diveDepth: 900,
        isCampaignUnlocked: true,
      );
      expect(ref.isChallenge, isTrue);
    });

    test('nothing is your own until the ladder is open', () {
      final ref = resolveSharedRef(
        shared(240816, 1),
        diveSeed: 240816,
        diveDepth: 1,
        isCampaignUnlocked: false,
        isLadderOpen: false,
      );
      expect(ref.isChallenge, isTrue);
    });

    test('a campaign level follows whether it is unlocked', () {
      final code = ShareCode.parse('L2-4')!;
      expect(
        resolveSharedRef(
          code,
          diveSeed: 1,
          diveDepth: 1,
          isCampaignUnlocked: true,
        ).isChallenge,
        isFalse,
      );
      expect(
        resolveSharedRef(
          code,
          diveSeed: 1,
          diveDepth: 1,
          isCampaignUnlocked: false,
        ).isChallenge,
        isTrue,
      );
    });
  });
}
