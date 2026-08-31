import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/level/level_catalog.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/home/home_screen.dart';
import 'package:quadcraft/features/play/play_screen.dart';
import 'package:quadcraft/ui/theme.dart';

void main() {
  late MemoryProgressStore store;

  Widget host({bool tutorialDone = false}) {
    store = MemoryProgressStore();
    if (tutorialDone) {
      for (var level = 1; level <= kTutorialLevelCount; level++) {
        store.recordClear(levelNumber: level, moves: 3);
      }
    }
    return ProviderScope(
      overrides: [
        progressStoreProvider.overrideWithValue(store),
        soundBankProvider.overrideWithValue(SoundBank.silent()),
      ],
      child: MaterialApp(theme: AppTheme.build(), home: const HomeScreen()),
    );
  }

  // The home screen animates forever, so every wait here is an explicit pump
  // rather than pumpAndSettle.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openSheet(
    WidgetTester tester, {
    bool tutorialDone = false,
  }) async {
    await tester.pumpWidget(host(tutorialDone: tutorialDone));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('home-shared-level')));
    await settle(tester);
  }

  testWidgets('a code has to name a level before it can be opened', (
    tester,
  ) async {
    await openSheet(tester);

    final open = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('share-code-open')),
        matching: find.byType(InkWell),
      ),
    );
    expect(open.onTap, isNull);

    await tester.enterText(find.byKey(const Key('share-code-field')), 'nope');
    await tester.pump();
    expect(find.text('That is not a Quadcraft code.'), findsOneWidget);
  });

  testWidgets('a good code previews the level it names', (tester) async {
    await openSheet(tester);

    await tester.enterText(
      find.byKey(const Key('share-code-field')),
      '4242-3-11',
    );
    await settle(tester);

    expect(find.text('That is not a Quadcraft code.'), findsNothing);
    expect(find.text('Level 03'), findsOneWidget);
    expect(find.text('To beat: 11 moves'), findsOneWidget);
  });

  testWidgets('opening a shared code lands on the level as a challenge', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(
      find.byKey(const Key('share-code-field')),
      '4242-3-11',
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('share-code-open')));
    await settle(tester);

    final screen = tester.widget<PlayScreen>(find.byType(PlayScreen));
    expect(screen.level.isChallenge, isTrue);
    expect(screen.level.seed, 4242);
    expect(screen.level.number, 3);
    expect(screen.movesToBeat, 11);
    // The dive is untouched by merely opening somebody else's level.
    expect(store.diveRun().seed, isNot(4242));
  });

  testWidgets('a challenge carries the score to beat into the HUD', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(
      find.byKey(const Key('share-code-field')),
      '4242-3-11',
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('share-code-open')));
    await settle(tester);

    // Dismiss the target intro so the header is on show.
    await tester.tap(find.byKey(const Key('target-intro')));
    await settle(tester);

    expect(find.text('SHARED LEVEL'), findsOneWidget);
    // A move counter means nothing on somebody else's level without the
    // number it has to come in under.
    expect(find.text('To beat: 11 moves'), findsOneWidget);
  });

  testWidgets('before the lessons are done, nothing is your own', (
    tester,
  ) async {
    await openSheet(tester);

    final seed = store.diveRun().seed;
    await tester.enterText(
      find.byKey(const Key('share-code-field')),
      '$seed-1',
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('share-code-open')));
    await settle(tester);

    // Even your own seed cannot bank a clear before you have a ladder.
    final screen = tester.widget<PlayScreen>(find.byType(PlayScreen));
    expect(screen.level.isChallenge, isTrue);
  });

  testWidgets('a depth on your own seed opens as your own level', (
    tester,
  ) async {
    await openSheet(tester, tutorialDone: true);

    final seed = store.diveRun().seed;
    await tester.enterText(
      find.byKey(const Key('share-code-field')),
      '$seed-1-9',
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('share-code-open')));
    await settle(tester);

    final screen = tester.widget<PlayScreen>(find.byType(PlayScreen));
    expect(screen.level.isChallenge, isFalse);
    expect(screen.level.number, 1);
  });
}
