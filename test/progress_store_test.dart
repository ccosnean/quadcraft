import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/data/progress_store.dart';

void main() {
  test('progress store survives a reload from disk', () {
    final dir = Directory.systemTemp.createTempSync('quadcraft-progress');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    final file = File('${dir.path}/quadcraft-progress.json');
    final first = ProgressStore(file)
      ..muted = true
      ..recordClear(levelNumber: 1, moves: 4)
      ..recordClear(levelNumber: 1, moves: 3);

    expect(first.muted, isTrue);
    expect(first.recordFor(1)?.bestMoves, 3);
    expect(first.recordFor(1)?.clears, 2);

    final reloaded = ProgressStore(file);
    expect(reloaded.muted, isTrue);
    expect(reloaded.recordFor(1)?.bestMoves, 3);
    expect(reloaded.highestUnlocked(3), 2);
  });
}
