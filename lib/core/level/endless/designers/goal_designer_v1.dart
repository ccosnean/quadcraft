import '../../../shape/shape.dart';
import '../../level.dart';
import '../endless_tuning.dart';
import '../goal_designer.dart';
import '../seed_random.dart';

/// How the four corners relate to each other. Targets drawn on a symmetry read
/// as an emblem rather than as noise, and they cost fewer moves because one
/// blueprint can fill a whole group at once — so the dive leans on symmetry
/// early and lets it go as it deepens.
enum _Symmetry {
  /// One stack, all four corners.
  full([
    [Corner.tl, Corner.tr, Corner.bl, Corner.br],
  ]),

  /// Mirrored left to right: the top row matches, the bottom row matches.
  rows([
    [Corner.tl, Corner.tr],
    [Corner.bl, Corner.br],
  ]),

  /// Mirrored top to bottom.
  columns([
    [Corner.tl, Corner.bl],
    [Corner.tr, Corner.br],
  ]),

  /// A half turn maps the plate onto itself.
  diagonal([
    [Corner.tl, Corner.br],
    [Corner.tr, Corner.bl],
  ]),

  /// One matched pair, and the rest of the plate free. Not a symmetry of the
  /// whole target, but a rhyme inside it — enough to read as arranged rather
  /// than scattered, and the only order an odd number of corners can hold.
  pair([]),

  /// Every corner for itself.
  free([]);

  const _Symmetry(this.groups);

  /// The corner groups this plan implies, where it has fixed ones. [pair] and
  /// [free] size themselves from the tuning instead, so they carry none.
  final List<List<Corner>> groups;
}

/// Every way two corners can mirror each other: the two rows, the two columns,
/// and the two diagonals.
const List<List<Corner>> _pairings = [
  [Corner.tl, Corner.tr],
  [Corner.bl, Corner.br],
  [Corner.tl, Corner.bl],
  [Corner.tr, Corner.br],
  [Corner.tl, Corner.br],
  [Corner.tr, Corner.bl],
];

/// The original dive designer.
///
/// Draws a target by choosing how its corners relate to each other, filling
/// each group with one stack of geometry, and then optionally handing part of
/// the finished thing back to the player as a head start.
class GoalDesignerV1 implements GoalDesigner {
  const GoalDesignerV1();

  @override
  String get id => 'v1';

  @override
  LevelDraft draft(SeedRandom rng, EndlessTuning tuning) {
    // The symmetry is chosen first, and it decides how many corners get
    // filled. It used to be the other way round, and that quietly capped how
    // ordered the dive could ever look.
    //
    // The corner count was rolled first, from a range that is {3, 4} for most
    // of the ladder. A three-corner target cannot be invariant under any
    // mirror or half turn — the empty quadrant has nowhere to map to — so half
    // of every batch was incapable of symmetry before the symmetry roll was
    // even reached. The roll then returned `free` for those anyway, because
    // its options only covered counts of two and four. Measured over 4800
    // targets, 29% read as symmetric against a `symmetryChance` of 0.7 to 0.92.
    final symmetry = _pickSymmetry(rng, tuning);
    final groups = _plan(rng, symmetry, tuning);
    final palette = _pickPalette(rng, tuning);
    // One vocabulary of geometry per target, so a level reads as a family of
    // pieces rather than as everything the dive has unlocked so far.
    final forms = rng.take(
      tuning.forms,
      rng.range(1, tuning.maxForms).clamp(1, tuning.forms.length),
    );

    var goal = Shape.empty;
    for (var index = 0; index < groups.length; index++) {
      final depth = rng.range(1, tuning.maxLayers);
      final stack = _stack(rng, depth, forms, palette, index);
      for (final corner in groups[index]) {
        goal = goal.withCorner(corner, Quadrant(stack));
      }
    }

    return _withStart(rng, tuning, goal);
  }

  static _Symmetry _pickSymmetry(SeedRandom rng, EndlessTuning tuning) {
    if (rng.chance(tuning.symmetryChance)) {
      // `full` twice: one stack repeated four times is the clearest emblem the
      // plate can hold, and the cheapest to build.
      return rng.pick(const [
        _Symmetry.full,
        _Symmetry.full,
        _Symmetry.rows,
        _Symmetry.columns,
        _Symmetry.diagonal,
      ]);
    }
    // Even the targets that are not symmetric mostly keep a rhyme. Fully free
    // corners stay in the mix, because a dive of nothing but emblems has no
    // texture, but they are now the exception rather than half the ladder.
    return rng.chance(tuning.pairChance) ? _Symmetry.pair : _Symmetry.free;
  }

  /// Which corners share a stack.
  static List<List<Corner>> _plan(
    SeedRandom rng,
    _Symmetry symmetry,
    EndlessTuning tuning,
  ) {
    switch (symmetry) {
      case _Symmetry.full:
        return symmetry.groups;

      case _Symmetry.rows:
      case _Symmetry.columns:
      case _Symmetry.diagonal:
        final pairs = [...symmetry.groups];
        rng.shuffle(pairs);
        // Both halves fill the plate. One half leaves the other empty, which
        // is still a mirror of itself but only allowed where the depth is
        // still content with a two-corner target.
        if (tuning.minCorners <= 2 && rng.chance(0.28)) {
          return [pairs.first];
        }
        return pairs;

      case _Symmetry.pair:
        final pair = rng.pick(_pairings);
        final rest = [
          for (final corner in Corner.values)
            if (!pair.contains(corner)) corner,
        ];
        rng.shuffle(rest);
        final fewest = (tuning.minCorners - 2).clamp(0, rest.length);
        final most = (tuning.maxCorners - 2).clamp(0, rest.length);
        // Leans towards leaving a corner empty. Exact symmetry needs two or
        // four filled quadrants, so pushing the dive towards order also pushes
        // every plate towards being full — and a ladder of nothing but full
        // plates has one silhouette. This is where the odd-cornered shapes
        // come back, still carrying a matched pair so they read as arranged.
        final extra = most > fewest && rng.chance(0.62) ? fewest : most;
        return [
          pair,
          for (final corner in rest.take(extra)) [corner],
        ];

      case _Symmetry.free:
        final count = rng.range(tuning.minCorners, tuning.maxCorners);
        return [
          for (final corner in rng.take(Corner.values, count)) [corner],
        ];
    }
  }

  static List<LayerPiece> _stack(
    SeedRandom rng,
    int depth,
    List<QuadForm> forms,
    _ColorPlan palette,
    int group,
  ) {
    // Nesting the same geometry twice reads as one thicker piece, so a corner
    // works through distinct forms first and only repeats once it runs out.
    final wheel = [...forms];
    rng.shuffle(wheel);
    final layers = <LayerPiece>[];
    for (var index = 0; index < depth; index++) {
      final form = wheel[index % wheel.length];
      final piece = LayerPiece(form, palette.colorAt(rng, index, group));
      if (layers.isNotEmpty && layers.last == piece) continue;
      layers.add(piece);
    }
    return layers.isEmpty
        ? [LayerPiece(wheel.first, palette.colorAt(rng, 0, group))]
        : layers;
  }

  static _ColorPlan _pickPalette(SeedRandom rng, EndlessTuning tuning) {
    if (tuning.maxColorsInGoal == 0 || tuning.palette.isEmpty) {
      return const _ColorPlan.bare();
    }
    final count = rng.range(1, tuning.maxColorsInGoal);
    final colors = rng.take(tuning.palette, count);
    if (colors.length == 1) {
      // A single colour on every piece is the cleanest read, and the cheapest
      // line: build the whole thing raw and dye it in one pass at the end.
      return _ColorPlan.wash(colors.first);
    }
    // Rings of colour or a colour per corner both stay legible at a glance.
    // Colour per piece does not, so it stays a garnish.
    final roll = rng.nextDouble();
    if (roll < 0.42) return _ColorPlan.banded(colors);
    if (roll < 0.85) return _ColorPlan.byCorner(colors);
    return _ColorPlan.mixed(colors);
  }

  /// Decides what the plate already holds. A gift is always the outer shell of
  /// its corner — drops slide underneath, so nothing else could ever be
  /// reached — and it may be dyed a colour this level cannot mix, which turns
  /// "save it before you paint" from an option into the puzzle.
  static LevelDraft _withStart(SeedRandom rng, EndlessTuning tuning, Shape goal) {
    // Gifts are handed out to whole sets of identical-looking corners.
    //
    // Not to the groups the target was drawn from, which was the obvious unit
    // and the wrong one. Two groups can roll the same stack by chance, and a
    // coincidence the player can see is as much a symmetry as a designed one.
    // Since a gift is usually also a recolour — into a shade the level cannot
    // mix, which is the whole puzzle — handing over one half of a matched pair
    // takes a plate drawn on a mirror and leaves it lopsided. Measured, gifted
    // targets came in 17 points less symmetric than ungifted ones until the
    // unit was changed from "group" to "looks the same".
    final classes = <Quadrant, List<Corner>>{};
    for (final corner in goal.filledCorners) {
      (classes[goal[corner]] ??= <Corner>[]).add(corner);
    }
    final filled = classes.values.toList();

    if (filled.isEmpty || !rng.chance(tuning.giftChance)) {
      return LevelDraft(
        start: Shape.empty,
        goal: goal,
        theme: _themeFor(rng, goal, Shape.empty),
      );
    }

    final shellCandidates = [
      for (final matched in filled)
        if (goal[matched.first].depth >= 2) matched,
    ];
    final wantsShell =
        shellCandidates.isNotEmpty && rng.chance(tuning.shellChance);

    final depths = <Corner, int>{};
    if (wantsShell) {
      final count = rng.range(1, shellCandidates.length);
      for (final matched in rng.take(shellCandidates, count)) {
        // One depth across the whole set, so the lining stays mirrored too.
        final keep = rng.range(1, goal[matched.first].depth - 1);
        for (final corner in matched) {
          depths[corner] = keep;
        }
      }
    } else {
      // A finished set is only a gift if another one is still to build.
      if (filled.length < 2) {
        return LevelDraft(
          start: Shape.empty,
          goal: goal,
          theme: _themeFor(rng, goal, Shape.empty),
        );
      }
      final count = rng.range(1, filled.length - 1);
      for (final matched in rng.take(filled, count)) {
        for (final corner in matched) {
          depths[corner] = goal[corner].depth;
        }
      }
    }

    var dressed = goal;
    final relic = _relicColor(rng, tuning, goal, depths);
    if (relic != null) dressed = _recolor(goal, depths, relic);

    final start = Shape({
      for (final entry in depths.entries)
        entry.key: Quadrant(dressed[entry.key].layers.sublist(0, entry.value)),
    });
    return LevelDraft(
      start: start,
      goal: dressed,
      theme: _themeFor(rng, dressed, start),
    );
  }

  /// A colour for the gift that this level has no way of mixing, so the only
  /// way to keep it is to bank it before the first coat.
  static QuadColor? _relicColor(
    SeedRandom rng,
    EndlessTuning tuning,
    Shape goal,
    Map<Corner, int> depths,
  ) {
    if (tuning.palette.isEmpty || !rng.chance(0.7)) return null;

    final elsewhere = <QuadColor>{};
    for (final corner in Corner.values) {
      final keep = depths[corner] ?? 0;
      for (final piece in goal[corner].layers.skip(keep)) {
        elsewhere.add(piece.color);
      }
    }
    final options = [
      for (final color in tuning.palette)
        if (!elsewhere.contains(color)) color,
    ];
    if (options.isEmpty) return null;

    final candidate = rng.pick(options);
    // Refuse a coat that would fuse two neighbouring layers into one blur.
    final painted = _recolor(goal, depths, candidate);
    for (final corner in Corner.values) {
      final layers = painted[corner].layers;
      for (var i = 1; i < layers.length; i++) {
        if (layers[i] == layers[i - 1]) return null;
      }
    }
    return candidate;
  }

  static Shape _recolor(Shape goal, Map<Corner, int> depths, QuadColor color) {
    var out = goal;
    for (final entry in depths.entries) {
      final layers = [...goal[entry.key].layers];
      for (var i = 0; i < entry.value; i++) {
        layers[i] = layers[i].painted(color);
      }
      out = out.withCorner(entry.key, Quadrant(layers));
    }
    return out;
  }

  /// Which line to print under the target. Several tags often fit one puzzle;
  /// the seed picks between them so a long dive does not repeat itself.
  static LevelTheme _themeFor(SeedRandom rng, Shape goal, Shape start) {
    if (start.isNotEmpty) {
      final hasLining = Corner.values.any(
        (corner) =>
            start[corner].isNotEmpty &&
            goal[corner].depth > start[corner].depth,
      );
      return hasLining ? LevelTheme.shell : LevelTheme.relic;
    }

    final colors = <QuadColor>{
      for (final corner in Corner.values)
        for (final piece in goal[corner].layers) piece.color,
    }..remove(QuadColor.uncolored);

    final options = <LevelTheme>[
      if (colors.length == 1) LevelTheme.wash,
      if (goal.depth >= 3) LevelTheme.nested,
      if (colors.length >= 2) LevelTheme.spectrum,
    ];
    return options.isEmpty ? LevelTheme.open : rng.pick(options);
  }
}

/// How colour is handed out across a target.
class _ColorPlan {
  const _ColorPlan.bare()
    : _style = _ColorStyle.bare,
      _colors = const [],
      _single = QuadColor.uncolored;

  const _ColorPlan.wash(QuadColor color)
    : _style = _ColorStyle.wash,
      _colors = const [],
      _single = color;

  const _ColorPlan.banded(this._colors)
    : _style = _ColorStyle.banded,
      _single = QuadColor.uncolored;

  const _ColorPlan.byCorner(this._colors)
    : _style = _ColorStyle.byCorner,
      _single = QuadColor.uncolored;

  const _ColorPlan.mixed(this._colors)
    : _style = _ColorStyle.mixed,
      _single = QuadColor.uncolored;

  final _ColorStyle _style;
  final List<QuadColor> _colors;
  final QuadColor _single;

  QuadColor colorAt(SeedRandom rng, int layerIndex, int group) =>
      switch (_style) {
        _ColorStyle.bare => QuadColor.uncolored,
        _ColorStyle.wash => _single,
        _ColorStyle.banded => _colors[layerIndex % _colors.length],
        _ColorStyle.byCorner => _colors[group % _colors.length],
        _ColorStyle.mixed => rng.pick(_colors),
      };
}

enum _ColorStyle { bare, wash, banded, byCorner, mixed }
