import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/core/level/level.dart';
import 'package:quadcraft/core/level/level_catalog.dart';
import 'package:quadcraft/core/level/levels.dart';

void main() {
  test('the hand-authored set is all tutorial', () {
    expect(kTutorialLevelCount, kLevels.length);
    for (final level in kLevels) {
      expect(level.section, startsWith('Tutorial'));
    }
  });

  test('the last tutorial level runs into the first generated depth', () {
    final last = LevelRef.campaign(kTutorialLevelCount);
    final next = nextAfter(last, seed: 4242);
    expect(next.kind, LevelKind.endless);
    expect(next.number, 1);
    expect(next.seed, 4242);

    // ...and mid-tutorial still walks the tutorial.
    final mid = nextAfter(LevelRef.campaign(2), seed: 4242);
    expect(mid.kind, LevelKind.campaign);
    expect(mid.number, 3);

    // The generated ladder simply keeps going.
    final deeper = nextAfter(
      LevelRef.endless(seed: 4242, number: 9),
      seed: 4242,
    );
    expect(deeper, LevelRef.endless(seed: 4242, number: 10));
    expect(hasLevelAfter(LevelRef.endless(seed: 4242, number: 999)), isTrue);
  });
}
