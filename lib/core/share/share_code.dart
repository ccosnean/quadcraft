import 'package:flutter/foundation.dart';

import '../level/level.dart';
import '../level/level_catalog.dart';

/// Host that serves share links, or null while there is not one.
///
/// A QR code is permanent the moment it is in somebody's camera roll, so
/// nothing ships pointing at a domain we do not control yet: until this is
/// set, a card carries the plain code and the player types it in. Set it once
/// and every card printed afterwards carries the URL instead — the parser
/// already reads both, so old codes keep working forever.
const String? kShareHost = null;

/// Custom scheme, for the day the app registers one. Parsed already so a link
/// minted by a later build is never unreadable to an earlier one.
const String kShareScheme = 'quadcraft';

/// A level someone handed you: which puzzle, and what they scored on it.
@immutable
class SharedLevel {
  const SharedLevel({required this.ref, this.movesToBeat});

  /// Always flagged as a challenge — it came from somebody else's run.
  final LevelRef ref;

  /// Moves the sharer took, when the code carried them.
  final int? movesToBeat;

  @override
  bool operator ==(Object other) =>
      other is SharedLevel &&
      other.ref == ref &&
      other.movesToBeat == movesToBeat;

  @override
  int get hashCode => Object.hash(ref, movesToBeat);

  @override
  String toString() => 'SharedLevel($ref, beat: $movesToBeat)';
}

/// Turns a level into something a player can pass to a friend, and back.
///
/// A generated level is fully described by `(seed, depth)`, so a code is just
/// those two numbers with the sharer's score on the end: `240816-12-14` reads
/// as "seed 240816, depth 12, done in 14". Decimal rather than packed, because
/// the seed is already a number the player sees in settings and reads out
/// loud, and a code you can say over the phone is worth more than a short one.
///
/// There is deliberately no checksum. A typo lands on a different but valid
/// puzzle, which the share image gives away instantly: the target on the card
/// will not be the target on screen.
abstract final class ShareCode {
  /// Marks a campaign level, which has no seed.
  static const String _campaignTag = 'L';

  /// Highest seed the generator can tell apart — it folds to 32 bits.
  static const int _maxSeed = 0xFFFFFFFF;

  static const int _maxDepth = 999999;
  static const int _maxMoves = 999999;

  /// The typed form: `240816-12-14`, or `L7-14` for a campaign level.
  static String encode(LevelRef ref, {int? moves}) {
    final tail = moves == null ? '' : '-$moves';
    return switch (ref.kind) {
      LevelKind.campaign => '$_campaignTag${ref.number}$tail',
      LevelKind.endless => '${ref.seed}-${ref.number}$tail',
    };
  }

  /// The link form, or null while no host serves it.
  static String? link(LevelRef ref, {int? moves}) {
    if (kShareHost == null) return null;
    final query = moves == null ? '' : '?m=$moves';
    final path = switch (ref.kind) {
      LevelKind.campaign => 'l/${ref.number}',
      LevelKind.endless => 'd/${ref.seed}/${ref.number}',
    };
    return 'https://$kShareHost/$path$query';
  }

  /// What the QR on the share card carries: the link where there is one, the
  /// bare code otherwise. Either way [parse] reads it back.
  static String payload(LevelRef ref, {int? moves}) =>
      link(ref, moves: moves) ?? encode(ref, moves: moves);

  /// Reads anything a player might paste: a code, a link, a code with the app
  /// name in front of it. Returns null for everything else — a wrong code is
  /// never worth guessing at.
  static SharedLevel? parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('://')) return _parseUri(trimmed);
    return _parseCode(trimmed);
  }

  static SharedLevel? _parseUri(String input) {
    final uri = Uri.tryParse(input);
    if (uri == null) return null;

    // `https://host/d/240816/12` and `quadcraft://d/240816/12` differ only in
    // whether the marker landed in the authority, so read them as one list.
    final segments = <String>[
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ].where((segment) => segment.isNotEmpty).toList();

    final moves = _number(uri.queryParameters['m'], max: _maxMoves);

    // Query form, for a link that has to survive a redirect or a share sheet
    // that mangles paths: ?s=240816&d=12.
    final seedParam = _number(uri.queryParameters['s'], max: _maxSeed);
    final depthParam = _number(uri.queryParameters['d'], max: _maxDepth);
    if (seedParam != null && depthParam != null) {
      return _endless(seedParam, depthParam, moves);
    }

    for (var i = 0; i < segments.length; i++) {
      final marker = segments[i].toLowerCase();
      if (marker == 'd' && i + 2 < segments.length) {
        final seed = _number(segments[i + 1], max: _maxSeed);
        final depth = _number(segments[i + 2], max: _maxDepth);
        if (seed != null && depth != null) return _endless(seed, depth, moves);
      }
      if (marker == 'l' && i + 1 < segments.length) {
        final number = _number(segments[i + 1], max: _maxDepth);
        if (number != null) return _campaign(number, moves);
      }
    }

    // Last resort: the code itself pasted as the final path segment.
    return segments.isEmpty ? null : _parseCode(segments.last);
  }

  static SharedLevel? _parseCode(String input) {
    // Tolerate decoration people add by hand: a name in front, spaces,
    // dashes of the wrong sort, lowercase.
    final cleaned = input
        .toUpperCase()
        .replaceAll(RegExp(r'[‐-―−]'), '-')
        .replaceAll(RegExp(r'^QUADCRAFT[\s:-]*'), '')
        .replaceAll(RegExp(r'^QC[\s:-]*'), '')
        .replaceAll(RegExp(r'\s'), '');
    if (cleaned.isEmpty) return null;

    final parts = cleaned.split('-').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty || parts.length > 3) return null;

    if (parts.first.startsWith(_campaignTag)) {
      final head = parts.first.substring(_campaignTag.length);
      final number = _number(head.isEmpty ? null : head, max: _maxDepth);
      // `L-7` splits differently from `L7`; both mean campaign level 7.
      final fromSecond = number == null && parts.length >= 2
          ? _number(parts[1], max: _maxDepth)
          : null;
      final level = number ?? fromSecond;
      if (level == null) return null;
      final movesIndex = number == null ? 2 : 1;
      final moves = parts.length > movesIndex
          ? _number(parts[movesIndex], max: _maxMoves)
          : null;
      if (parts.length > movesIndex && moves == null) return null;
      return _campaign(level, moves);
    }

    if (parts.length < 2) return null;
    final seed = _number(parts[0], max: _maxSeed);
    final depth = _number(parts[1], max: _maxDepth);
    if (seed == null || depth == null) return null;
    final moves = parts.length > 2 ? _number(parts[2], max: _maxMoves) : null;
    if (parts.length > 2 && moves == null) return null;
    return _endless(seed, depth, moves);
  }

  static SharedLevel _endless(int seed, int depth, int? moves) => SharedLevel(
    ref: LevelRef.endless(seed: seed, number: depth, isChallenge: true),
    movesToBeat: moves,
  );

  static SharedLevel? _campaign(int number, int? moves) {
    // A campaign number nobody has is a dead link, not a puzzle.
    if (number > kTutorialLevelCount) return null;
    return SharedLevel(
      ref: LevelRef.campaign(number, isChallenge: true),
      movesToBeat: moves,
    );
  }

  /// A positive whole number in range, or null. Rejects `+1`, `1.0` and the
  /// rest rather than reading them charitably.
  static int? _number(String? raw, {required int max}) {
    if (raw == null || raw.isEmpty) return null;
    if (!RegExp(r'^\d+$').hasMatch(raw)) return null;
    final value = int.tryParse(raw);
    if (value == null || value < 1 || value > max) return null;
    return value;
  }
}
