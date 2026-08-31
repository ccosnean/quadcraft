import 'endless/endless_levels.dart';
import 'level.dart';
import 'levels.dart';

/// The hand-authored levels, all of which are tutorial. Clearing them is what
/// opens the generated ladder, so the generator never has to explain itself.
final int kTutorialLevelCount = kLevels.length;

/// The one place that turns a reference into a playable level, whichever side
/// of the game it came from.
Level levelFor(LevelRef ref) => switch (ref.kind) {
  LevelKind.campaign => levelByNumber(ref.number),
  LevelKind.endless => EndlessLevels.forRef(ref),
};

/// Whether [ref] has something after it. The generated ladder never runs out,
/// and the tutorial runs straight into its first depth.
bool hasLevelAfter(LevelRef ref) => true;

/// The level that follows [ref]. The end of the tutorial rolls over into the
/// first generated depth, so "next" never dead-ends.
LevelRef nextAfter(LevelRef ref, {required int seed}) {
  if (ref.kind == LevelKind.endless) return ref.next();
  return ref.number < kTutorialLevelCount
      ? LevelRef.campaign(ref.number + 1)
      : LevelRef.endless(seed: seed, number: 1);
}

/// Ceiling on how far the level list will build. Nothing a player reaches —
/// the dive itself has no end — but a list has to stop somewhere, and this is
/// far enough down that it never will in practice.
const int kMaxRevealedDepths = 100000;

