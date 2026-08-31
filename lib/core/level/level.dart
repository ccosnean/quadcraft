import 'package:flutter/foundation.dart';

import '../shape/shape.dart';

/// A single player action.
@immutable
sealed class GameMove {
  const GameMove();

  /// Short label used by the hint sheet.
  String get label;
}

class RotateMove extends GameMove {
  const RotateMove();

  @override
  String get label => 'Rotate';
}

class CutMove extends GameMove {
  const CutMove();

  @override
  String get label => 'Cut';
}

/// Drops the tray blueprint identified by [shapeId] onto the board.
class StackMove extends GameMove {
  const StackMove(this.shapeId);

  final String shapeId;

  @override
  String get label => 'Place';
}

class PaintMove extends GameMove {
  const PaintMove(this.color);

  final QuadColor color;

  @override
  String get label => 'Paint';
}

/// Where a level came from. Campaign levels are hand-authored; endless levels
/// are grown from a run seed and a depth.
enum LevelKind { campaign, endless }

/// The shape of the puzzle, in one word. Endless levels have no authored
/// brief, so the UI renders a localized line from this tag instead.
enum LevelTheme {
  /// Nothing on the plate — build the whole target from scratch.
  open,

  /// One colour for everything: build raw, then dye the lot in one pass.
  wash,

  /// A gift on the plate is already the finished stack at its corner.
  relic,

  /// A gift on the plate is the outer shell; its lining is still missing.
  shell,

  /// Deep quadrants — several pieces nested in the same corner.
  nested,

  /// Several palettes in one target; each colour needs its own trip.
  spectrum,
}

/// Addresses a playable level without materialising it.
///
/// Campaign levels are looked up by number; endless levels are regenerated
/// from `(seed, number)` every time, so the reference is all that needs to be
/// passed around, stored in a route, or used as a provider family key.
@immutable
class LevelRef {
  const LevelRef.campaign(this.number, {this.isChallenge = false})
    : kind = LevelKind.campaign,
      seed = 0;

  const LevelRef.endless({
    required this.seed,
    required this.number,
    this.isChallenge = false,
  }) : kind = LevelKind.endless;

  final LevelKind kind;

  /// Level number for the campaign, dive depth for endless.
  final int number;

  /// Run seed. Always 0 for the campaign.
  final int seed;

  /// Opened from somebody else's share code rather than off this player's own
  /// ladder. The puzzle is identical — only what clearing it means changes:
  /// a challenge writes nothing, because a depth on a stranger's seed is not
  /// a rung of your dive and a score against it is not your score.
  final bool isChallenge;

  bool get isEndless => kind == LevelKind.endless;

  LevelRef next() => switch (kind) {
    LevelKind.campaign => LevelRef.campaign(
      number + 1,
      isChallenge: isChallenge,
    ),
    LevelKind.endless => LevelRef.endless(
      seed: seed,
      number: number + 1,
      isChallenge: isChallenge,
    ),
  };

  /// The same puzzle, played as somebody else's.
  LevelRef asChallenge() => switch (kind) {
    LevelKind.campaign => LevelRef.campaign(number, isChallenge: true),
    LevelKind.endless => LevelRef.endless(
      seed: seed,
      number: number,
      isChallenge: true,
    ),
  };

  /// The same puzzle, played as your own.
  LevelRef asOwn() => switch (kind) {
    LevelKind.campaign => LevelRef.campaign(number),
    LevelKind.endless => LevelRef.endless(seed: seed, number: number),
  };

  @override
  bool operator ==(Object other) =>
      other is LevelRef &&
      other.kind == kind &&
      other.number == number &&
      other.seed == seed &&
      other.isChallenge == isChallenge;

  @override
  int get hashCode => Object.hash(kind, number, seed, isChallenge);

  @override
  String toString() {
    final base = switch (kind) {
      LevelKind.campaign => 'level-$number',
      LevelKind.endless => 'endless-$seed-$number',
    };
    return isChallenge ? '$base-shared' : base;
  }
}

/// One puzzle: hand-authored in the campaign, grown from a seed in endless.
///
/// [solution] is the reference line the level was designed around. For the
/// campaign it is the authoring record replayed by the level tests so a broken
/// puzzle can never ship; for endless it is the line the generator *built* the
/// goal from, which is what makes every generated level provably completable.
/// Either way it is not shown to players — only the hint button spends it.
@immutable
class Level {
  const Level({
    required this.number,
    required this.name,
    required this.section,
    required this.brief,
    required this.goal,
    required this.solution,
    this.start = Shape.empty,
    this.tray = const <Shape>[],
    this.colors = const <QuadColor>[],
    this.canRotate = false,
    this.canCut = false,
    this.kind = LevelKind.campaign,
    this.seed = 0,
    this.theme,
    this.stratum = 0,
  });

  final int number;
  final String name;

  /// World / chapter label used to group levels in the select screen.
  final String section;

  /// Flavour line under the target. Teaches a feel, not the walkthrough.
  final String brief;

  final Shape goal;
  final Shape start;

  /// Blueprints the player starts with. Blueprints are never consumed.
  final List<Shape> tray;

  final List<QuadColor> colors;
  final bool canRotate;
  final bool canCut;
  final List<GameMove> solution;

  final LevelKind kind;

  /// Run seed for generated levels; 0 for the campaign.
  final int seed;

  /// Set on generated levels, where the brief is rendered from a tag.
  final LevelTheme? theme;

  /// Band of the endless dive this level belongs to.
  final int stratum;

  int get parMoves => solution.length;

  LevelRef get ref => switch (kind) {
    LevelKind.campaign => LevelRef.campaign(number),
    LevelKind.endless => LevelRef.endless(seed: seed, number: number),
  };

  String get id => ref.toString();
}
