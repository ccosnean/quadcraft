import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/level/endless/endless_levels.dart';
import '../../core/shape/shape.dart';

const _mirrorH = {
  Corner.tl: Corner.tr,
  Corner.tr: Corner.tl,
  Corner.bl: Corner.br,
  Corner.br: Corner.bl,
};
const _mirrorV = {
  Corner.tl: Corner.bl,
  Corner.bl: Corner.tl,
  Corner.tr: Corner.br,
  Corner.br: Corner.tr,
};
const _halfTurn = {
  Corner.tl: Corner.br,
  Corner.br: Corner.tl,
  Corner.tr: Corner.bl,
  Corner.bl: Corner.tr,
};
const _quarterTurn = {
  Corner.tl: Corner.tr,
  Corner.tr: Corner.br,
  Corner.br: Corner.bl,
  Corner.bl: Corner.tl,
};

bool _invariant(Shape shape, Map<Corner, Corner> under) {
  for (final corner in Corner.values) {
    if (shape[corner] != shape[under[corner]!]) return false;
  }
  return true;
}

bool _hasMatchedPair(Shape shape) {
  final filled = shape.filledCorners.toList();
  for (var i = 0; i < filled.length; i++) {
    for (var j = i + 1; j < filled.length; j++) {
      if (shape[filled[i]] == shape[filled[j]]) return true;
    }
  }
  return false;
}

/// How well a target would hold the title screen.
///
/// Symmetry first, by a wide margin — the shape turns on the spot up there, so
/// a lopsided one wobbles while a symmetric one spins. A quarter turn is worth
/// most because it is the only symmetry the rotation itself does not break:
/// four identical corners look the same at every step of the animation.
///
/// Everything below that is a tie-break towards a shape worth looking at. A
/// single bare circle is perfectly symmetric and says nothing about the game.
@visibleForTesting
int showcaseScore(Shape shape) {
  final filled = shape.filledCorners.length;
  if (filled == 0) return 0;

  final int symmetry;
  if (_invariant(shape, _quarterTurn)) {
    symmetry = 6;
  } else if (_invariant(shape, _mirrorH) || _invariant(shape, _mirrorV)) {
    symmetry = 4;
  } else if (_invariant(shape, _halfTurn)) {
    symmetry = 3;
  } else if (_hasMatchedPair(shape)) {
    symmetry = 1;
  } else {
    symmetry = 0;
  }

  return symmetry * 100 + filled * 10 + shape.depth.clamp(0, 4);
}

/// How many depths one complexity band covers, and how many bands are shown.
///
/// Six rather than four: a band is a pool to choose the best from, and every
/// depth added to it is another chance of finding a symmetric one. At four,
/// roughly one band in ten had nothing better than a matched pair in it.
const int _bandSpan = 6;
const int showcaseCount = 10;

/// The shapes the title screen turns over, taken from the player's own run.
///
/// One per complexity band, best-scoring of the six depths in it, so the
/// sequence climbs from something a beginner would recognise to something the
/// deep end would throw — and it is *their* ladder, not a set of samples that
/// exist nowhere in the game.
///
/// The scan is spread across frames rather than run up front. Sixty targets at
/// about 2.5 ms each is well over a tenth of a second of solver, and the title
/// screen is the first thing drawn: it opens with whatever is ready and fills
/// in behind the first rotation, which takes six seconds to come round anyway.
class ShowcaseShapes extends ChangeNotifier {
  ShowcaseShapes({required this.seed}) {
    _pump();
  }

  final int seed;

  static const Duration _budget = Duration(milliseconds: 4);

  final Map<int, Shape> _best = {};
  final Map<int, int> _bestScore = {};
  int _next = 1;
  bool _scheduled = false;
  bool _disposed = false;

  /// Best-scoring target per band, shallowest first. Grows as the scan runs.
  List<Shape> get shapes {
    final bands = _best.keys.toList()..sort();
    return [for (final band in bands) _best[band]!];
  }

  bool get isComplete => _next > _bandSpan * showcaseCount;

  void _pump() {
    if (_scheduled || _disposed || isComplete) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      final watch = Stopwatch()..start();
      var changed = false;
      while (!isComplete && watch.elapsed < _budget) {
        final depth = _next++;
        final band = (depth - 1) ~/ _bandSpan;
        final shape = EndlessLevels.levelAt(seed: seed, depth: depth).goal;
        final score = showcaseScore(shape);
        if (score > (_bestScore[band] ?? -1)) {
          _bestScore[band] = score;
          _best[band] = shape;
          changed = true;
        }
      }
      if (changed) notifyListeners();
      if (!isComplete) {
        _pump();
        SchedulerBinding.instance.scheduleFrame();
      }
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// One showcase per run, so re-seeding redraws the title screen too.
final showcaseProvider = Provider.autoDispose.family<ShowcaseShapes, int>((
  ref,
  seed,
) {
  final showcase = ShowcaseShapes(seed: seed);
  ref.onDispose(showcase.dispose);
  return showcase;
});
