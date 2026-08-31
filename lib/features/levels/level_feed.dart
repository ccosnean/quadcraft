import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/level/endless/endless_levels.dart';
import '../../core/level/level.dart';

/// Builds dive levels off the critical path.
///
/// A card asks for a level and gets whatever is ready; anything that is not is
/// queued and built inside a per-frame time budget, then filled in on a later
/// frame. Generating on demand inside the grid builder would be simpler and
/// would stutter: a level costs about 2.5 ms to design and check, the grid is
/// three columns wide, and a fast fling brings three to six new cards into
/// view per frame — 8 to 15 ms of a 16 ms frame spent in the planner before
/// anything is painted.
///
/// The cost does not grow with depth: depth 2000 measures the same as depth
/// 50. So there is no point at which the ladder stops working, and the only
/// thing that ever matters is how much of it lands inside one frame.
class LevelFeed extends ChangeNotifier {
  LevelFeed({required this.seed});

  /// The run these levels belong to. A new seed is a new feed.
  final int seed;

  /// How long one frame may spend building. Deliberately far under a frame:
  /// the list would rather show a placeholder for a moment than drop a frame.
  static const Duration _budget = Duration(milliseconds: 5);

  /// How far past the last card asked for to keep building anyway, so that
  /// scrolling on arrives at levels that already exist.
  static const int lookAhead = 12;

  final Queue<int> _wanted = Queue<int>();
  final Set<int> _pending = <int>{};
  bool _scheduled = false;
  bool _disposed = false;

  @visibleForTesting
  int get pendingCount => _wanted.length;

  /// The level for [depth] if it is ready, otherwise null — and queued.
  Level? peek(int depth) {
    final ready = EndlessLevels.cached(seed: seed, depth: depth);
    if (ready != null) return ready;
    request(depth);
    return null;
  }

  /// Queues [depth] without anyone having asked to see it yet.
  void request(int depth) {
    if (_disposed || depth < 1 || _pending.contains(depth)) return;
    if (EndlessLevels.cached(seed: seed, depth: depth) != null) return;
    _pending.add(depth);
    _wanted.add(depth);
    _pump();
  }

  /// Warms [count] depths from [from], for the cards just past the viewport.
  void prefetch(int from, int count) {
    for (var depth = from; depth < from + count; depth++) {
      request(depth);
    }
  }

  /// Builds whatever fits in [_budget] once the frame is on screen, then comes
  /// back for the rest. Running after the frame rather than during it is the
  /// point: a fling is never made to wait on the planner.
  void _pump() {
    if (_scheduled || _disposed || _wanted.isEmpty) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      final watch = Stopwatch()..start();
      var built = 0;
      while (_wanted.isNotEmpty && watch.elapsed < _budget) {
        final depth = _wanted.removeFirst();
        _pending.remove(depth);
        EndlessLevels.levelAt(seed: seed, depth: depth);
        built++;
      }
      if (built > 0) notifyListeners();
      if (_wanted.isNotEmpty) {
        _pump();
        // Nothing else may be asking for a frame once the list is at rest, and
        // a post-frame callback that never gets a frame never runs.
        SchedulerBinding.instance.scheduleFrame();
      }
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _disposed = true;
    _wanted.clear();
    _pending.clear();
    super.dispose();
  }
}

/// One feed per run. Disposed with the screen, so a re-seed starts clean.
final levelFeedProvider = Provider.autoDispose.family<LevelFeed, int>((
  ref,
  seed,
) {
  final feed = LevelFeed(seed: seed);
  ref.onDispose(feed.dispose);
  return feed;
});
