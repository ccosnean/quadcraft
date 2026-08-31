/// A tiny xorshift generator with explicit 32-bit arithmetic.
///
/// The point is portability, not statistical quality: a run seed is a number
/// players keep (and share), so the same seed has to grow the same dive on a
/// phone, on desktop and on the web build — where Dart ints are doubles and
/// anything wider than 32 bits would silently drift. `dart:math`'s Random is
/// also free to change between SDKs; this one cannot.
class SeedRandom {
  SeedRandom(int seed) : _state = _sanitize(seed);

  int _state;

  static int _sanitize(int seed) {
    final masked = seed & 0xFFFFFFFF;
    // Zero is a fixed point for xorshift, so nudge it off.
    return masked == 0 ? 0x9E3779B9 : masked;
  }

  int _next() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >>> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x & 0xFFFFFFFF;
    return _state;
  }

  /// Uniform in `[0, max)`.
  int nextInt(int max) {
    assert(max > 0);
    return _next() % max;
  }

  /// Uniform in `[min, max]`, inclusive.
  int range(int min, int max) =>
      max <= min ? min : min + nextInt(max - min + 1);

  double nextDouble() => _next() / 0x100000000;

  bool chance(double probability) => nextDouble() < probability;

  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// Fisher-Yates, in place.
  void shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final swap = items[i];
      items[i] = items[j];
      items[j] = swap;
    }
  }

  /// [count] distinct entries, in a shuffled order.
  List<T> take<T>(List<T> items, int count) {
    final copy = [...items];
    shuffle(copy);
    return copy.take(count).toList(growable: false);
  }
}

/// Folds several numbers into one 32-bit seed. Used so `(runSeed, depth,
/// attempt)` addresses a distinct, stable generator state.
int mixSeed(Iterable<int> parts) {
  var hash = 0x811C9DC5;
  for (final part in parts) {
    var value = part & 0xFFFFFFFF;
    for (var byte = 0; byte < 4; byte++) {
      hash ^= value & 0xFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
      value >>>= 8;
    }
  }
  // Final avalanche so neighbouring depths do not produce neighbouring states.
  hash ^= hash >>> 15;
  hash = (hash * 0x2545F491) & 0xFFFFFFFF;
  hash ^= hash >>> 13;
  return hash & 0xFFFFFFFF;
}
