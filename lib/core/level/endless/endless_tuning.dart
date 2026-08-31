import 'dart:math' as math;

import '../../shape/shape.dart';

/// Depths per named band, and per batch revealed in the level list.
const int kStratumSpan = 10;

/// Forms and colours arrive on a fixed schedule so the ladder has landmarks:
/// the first windmill, the first fourth colour, the first four-layer corner.
///
/// Depth 1 is the level *after* the tutorial, not a first puzzle — the player
/// arrives already knowing turn, place, stack, paint and cut. So the ladder
/// opens with a real vocabulary rather than a single bare circle: three forms
/// and two colours from the start. That is also what keeps seeds apart. A
/// depth whose rules admit only a handful of legal targets produces the same
/// target for every seed, which reads as the generator being broken.
const List<({int depth, QuadForm form})> kFormUnlocks = [
  (depth: 1, form: QuadForm.circle),
  (depth: 1, form: QuadForm.square),
  (depth: 1, form: QuadForm.star),
  (depth: 4, form: QuadForm.windmill),
  (depth: 10, form: QuadForm.pike),
  (depth: 16, form: QuadForm.leaf),
];

const List<({int depth, QuadColor color})> kColorUnlocks = [
  (depth: 1, color: QuadColor.red),
  (depth: 1, color: QuadColor.blue),
  (depth: 3, color: QuadColor.yellow),
  (depth: 6, color: QuadColor.green),
  (depth: 10, color: QuadColor.cyan),
  (depth: 14, color: QuadColor.purple),
  (depth: 19, color: QuadColor.orange),
  (depth: 24, color: QuadColor.magenta),
];

/// Something the ladder hands the player for the first time at a given depth.
sealed class DiveUnlock {
  const DiveUnlock(this.depth);

  final int depth;
}

class FormUnlock extends DiveUnlock {
  const FormUnlock(super.depth, this.form);

  final QuadForm form;
}

class ColorUnlock extends DiveUnlock {
  const ColorUnlock(super.depth, this.color);

  final QuadColor color;
}

class LayerUnlock extends DiveUnlock {
  const LayerUnlock(super.depth, this.layers);

  final int layers;
}

/// Everything the designer is allowed to use at one depth.
class EndlessTuning {
  const EndlessTuning({
    required this.depth,
    required this.forms,
    required this.palette,
    required this.maxLayers,
    required this.minCorners,
    required this.maxCorners,
    required this.maxForms,
    required this.maxTray,
    required this.maxColorsInGoal,
    required this.giftChance,
    required this.shellChance,
    required this.symmetryChance,
    required this.pairChance,
    required this.parTarget,
    required this.parFloor,
    required this.parCeiling,
  });

  factory EndlessTuning.forDepth(int depth) {
    final d = depth < 1 ? 1 : depth;
    final forms = formsAt(d);
    final palette = colorsAt(d);
    final maxColors = maxColorsInGoalAt(d);
    final target = _parTarget(d);

    return EndlessTuning(
      depth: d,
      forms: forms,
      palette: palette,
      maxLayers: maxLayersAt(d),
      minCorners: minCornersAt(d),
      maxCorners: maxCornersAt(d),
      maxForms: maxFormsAt(d, forms.length),
      maxTray: (3 + d ~/ 12).clamp(3, 5),
      maxColorsInGoal: maxColors > palette.length ? palette.length : maxColors,
      giftChance: d < 3 ? 0.0 : _clamp(0.18 + (d - 3) * 0.02, 0, 0.6),
      shellChance: d < 5 ? 0.0 : _clamp(0.25 + (d - 5) * 0.014, 0, 0.6),
      symmetryChance: _clamp(0.88 - (d - 1) * 0.007, 0.52, 1),
      pairChance: _clamp(0.85 - (d - 1) * 0.004, 0.55, 1),
      parTarget: target,
      parFloor: (target * 0.6).round().clamp(2, 30),
      parCeiling: (target * 1.35).round().clamp(4, 36),
    );
  }

  final int depth;

  /// Geometry the designer may draw from.
  final List<QuadForm> forms;

  /// Colours the level is allowed to offer in the paint tray.
  final List<QuadColor> palette;

  final int maxLayers;
  final int minCorners;
  final int maxCorners;

  /// Distinct geometries one target may draw on. Each one costs a slot in the
  /// tray, so a level that used everything unlocked would be unreadable long
  /// before it was hard.
  final int maxForms;

  /// Blueprints the level may open with. Past this the tray stops reading as a
  /// set of tools and starts reading as a wall.
  final int maxTray;

  /// How many distinct colours may appear in one target.
  final int maxColorsInGoal;

  /// Odds the plate starts with something already on it.
  final double giftChance;

  /// Given a gift, the odds it is only the outer shell of its corner rather
  /// than a finished stack.
  final double shellChance;

  /// Odds the target is drawn on an exact symmetry — a mirror or a half turn
  /// that maps the whole plate onto itself.
  final double symmetryChance;

  /// Given that it is not, the odds it at least carries one matched pair of
  /// corners rather than being drawn freehand. A plate of nothing but emblems
  /// has no texture, but scattered corners should be the exception, so most of
  /// what is left over still rhymes with itself.
  final double pairChance;

  /// Reference-line length the designer aims for. Drafts are scored on how far
  /// they land from it, which is what actually shapes the difficulty curve —
  /// the target grows quickly at first and then settles, because a hundredth
  /// level should be intricate, not merely long.
  final double parTarget;
  final int parFloor;
  final int parCeiling;

  /// 0-based band. Names cycle every six bands.
  int get stratum => (depth - 1) ~/ kStratumSpan;

  /// Saturating curve. Opens around ten moves — the tutorial's last puzzles
  /// already run that long — and eases onto a plateau in the low thirties.
  static double _parTarget(int depth) =>
      8.0 + 25.0 * (1 - math.exp(-(depth - 1) / 18.0));

  static double _clamp(double value, double min, double max) =>
      value < min ? min : (value > max ? max : value);

  static int maxLayersAt(int depth) =>
      (2 + (depth - 1) ~/ 7).clamp(2, Shape.maxLayers);

  static int maxCornersAt(int depth) => (3 + (depth - 1) ~/ 3).clamp(3, 4);

  static int maxFormsAt(int depth, int unlocked) =>
      (2 + depth ~/ 8).clamp(2, unlocked < 4 ? unlocked : 4);

  static int minCornersAt(int depth) =>
      depth < 3 ? 2 : (maxCornersAt(depth) - 1).clamp(2, 4);

  static int maxColorsInGoalAt(int depth) {
    if (depth <= 2) return 1;
    if (depth <= 8) return 2;
    if (depth <= 18) return 3;
    return 4;
  }

  static List<QuadForm> formsAt(int depth) => [
    for (final unlock in kFormUnlocks)
      if (unlock.depth <= depth) unlock.form,
  ];

  static List<QuadColor> colorsAt(int depth) => [
    for (final unlock in kColorUnlocks)
      if (unlock.depth <= depth) unlock.color,
  ];

  /// The next thing the ladder has not shown the player yet, or null once
  /// everything is unlocked.
  static DiveUnlock? nextUnlock(int depth) {
    final candidates = <DiveUnlock>[
      for (final unlock in kFormUnlocks) FormUnlock(unlock.depth, unlock.form),
      for (final unlock in kColorUnlocks)
        ColorUnlock(unlock.depth, unlock.color),
      for (var layers = 3; layers <= Shape.maxLayers; layers++)
        LayerUnlock((layers - 2) * 7 + 1, layers),
    ]..sort((a, b) => a.depth.compareTo(b.depth));

    for (final unlock in candidates) {
      if (unlock.depth > depth) return unlock;
    }
    return null;
  }
}
