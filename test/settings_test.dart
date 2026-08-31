import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/core/level/level.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/level/levels.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/home/home_screen.dart';
import 'package:quadcraft/features/levels/level_select_screen.dart';
import 'package:quadcraft/features/play/confetti.dart';
import 'package:quadcraft/features/play/play_screen.dart';
import 'package:quadcraft/features/settings/settings_screen.dart';
import 'package:quadcraft/l10n/l10n.dart';
import 'package:quadcraft/ui/theme.dart';

late MemoryProgressStore store;

Widget host(Widget child) {
  store = MemoryProgressStore();
  return ProviderScope(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      soundBankProvider.overrideWithValue(SoundBank.silent()),
    ],
    child: MaterialApp(theme: AppTheme.build(), home: child),
  );
}

Future<void> completeReset(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('reset-game')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('reset-game')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('reset-step-confirm')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('reset-understand')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('reset-step-confirm')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('reset-step-confirm')));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('settings persist sound, confetti and language', (tester) async {
    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(store.muted, isFalse);
    expect(store.confetti, ConfettiAmount.full);
    expect(store.languageCode, AppLanguage.fromPlatform().code);
    expect(store.targetPreview, TargetPreviewMode.auto);

    await tester.tap(find.byKey(const Key('sound-toggle')));
    await tester.pump();
    expect(store.muted, isTrue);

    await tester.tap(find.byKey(const Key('confetti-reduced')));
    await tester.pump();
    expect(store.confetti, ConfettiAmount.reduced);
    expect(store.confetti.particles, 18);

    await tester.tap(find.byKey(const Key('target-preview-off')));
    await tester.pump();
    expect(store.targetPreview, TargetPreviewMode.off);

    await tester.ensureVisible(find.byKey(const Key('language-es')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('language-es')));
    await tester.pump();
    expect(store.languageCode, 'es');
    expect(find.text('Ajustes'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('language-zh')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('language-zh')));
    await tester.pump();
    expect(store.languageCode, 'zh');
    expect(find.text('设置'), findsOneWidget);
    expect(find.byKey(const Key('objectbox-inspector')), findsOneWidget);
  });

  testWidgets('play screen applies the stored confetti amount', (tester) async {
    await tester.pumpWidget(
      host(const PlayScreen(level: LevelRef.campaign(1))),
    );
    await tester.pump(const Duration(milliseconds: 100));

    var burst = tester.widget<ConfettiBurst>(find.byType(ConfettiBurst));
    expect(burst.particles, 72);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    container.read(confettiProvider.notifier).set(ConfettiAmount.reduced);
    await tester.pump();
    burst = tester.widget<ConfettiBurst>(find.byType(ConfettiBurst));
    expect(burst.particles, 18);

    container.read(confettiProvider.notifier).set(ConfettiAmount.off);
    await tester.pump();
    burst = tester.widget<ConfettiBurst>(find.byType(ConfettiBurst));
    expect(burst.particles, 0);
  });

  testWidgets('reset from home returns to a fresh campaign', (tester) async {
    await tester.pumpWidget(host(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    container
        .read(progressProvider.notifier)
        .recordClear(levelNumber: 1, moves: 3);
    container.read(mutedProvider.notifier).toggle();
    container.read(confettiProvider.notifier).set(ConfettiAmount.off);
    await tester.pump();
    expect(find.text('1 of ${kLevels.length} solved'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SettingsScreen), findsOneWidget);

    await completeReset(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('0 of ${kLevels.length} solved'), findsOneWidget);
    expect(store.recordFor(1), isNull);
    expect(store.highestUnlocked(kLevels.length), 1);
    expect(store.muted, isFalse);
    expect(store.confetti, ConfettiAmount.full);
    expect(store.targetPreview, TargetPreviewMode.auto);
  });

  testWidgets('off target preview skips the intro overlay', (tester) async {
    final app = host(const PlayScreen(level: LevelRef.campaign(1)));
    store.targetPreview = TargetPreviewMode.off;
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('target-intro')), findsNothing);
  });

  testWidgets('auto target preview closes itself', (tester) async {
    await tester.pumpWidget(
      host(const PlayScreen(level: LevelRef.campaign(1))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('target-intro')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('target-intro')), findsNothing);
  });

  testWidgets('dont auto-open from the overlay stores Off', (tester) async {
    await tester.pumpWidget(
      host(const PlayScreen(level: LevelRef.campaign(1))),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('target-intro-dont-auto')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(store.targetPreview, TargetPreviewMode.off);
    expect(find.byKey(const Key('target-intro')), findsNothing);
  });

  testWidgets('play HUD briefs follow the UI language', (tester) async {
    final app = host(const PlayScreen(level: LevelRef.campaign(1)));
    store.languageCode = 'ro';
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Un sfert de tură, ca o cheie în broască.'),
      findsOneWidget,
    );
  });

  testWidgets('unlock everything opens the whole ladder without progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(host(const HomeScreen()));
    await tester.pump();

    // Nothing solved yet, so the list shows the tutorial locked past level 1
    // and no generated depths at all.
    await tester.tap(find.text('ALL LEVELS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LevelSelectScreen), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(LevelSelectScreen)),
      ).read(progressProvider).diveOpen,
      isFalse,
    );

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    for (var tick = 0; tick < 4; tick++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('dev-unlock-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dev-unlock-toggle')));
    await tester.pump();
    expect(store.devUnlockAll, isTrue);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    for (var tick = 0; tick < 4; tick++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(HomeScreen), findsOneWidget);

    // Still nothing actually cleared, but everything reads as open — the
    // tutorial unlocked end to end, and the first generated band revealed.
    expect(store.allRecords(), isEmpty);
    await tester.tap(find.text('ALL LEVELS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.lock_rounded), findsNothing);

    // The generated band sits past the whole tutorial, so scroll to it.
    await tester.scrollUntilVisible(
      find.text('The Shallows'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(find.text('The Shallows'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LevelSelectScreen)),
    );
    expect(
      container.read(progressProvider).isUnlocked(kLevels.last.number),
      isTrue,
    );
    expect(container.read(progressProvider).diveOpen, isTrue);
  });

  testWidgets('the tutorial can be reopened once it is behind you', (
    tester,
  ) async {
    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('replay-tutorial')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('replay-tutorial')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The lessons, not the ladder — and reachable even though this save has
    // cleared none of them.
    expect(find.byType(LevelSelectScreen), findsOneWidget);
    expect(find.text('Tutorial'), findsOneWidget);
    expect(find.text('First Turn'), findsOneWidget);
  });

  testWidgets('the tutorial can be skipped and is still there after', (
    tester,
  ) async {
    await tester.pumpWidget(host(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('home-skip-tutorial')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-skip-tutorial')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The ladder is open and the front page leads to it instead.
    expect(store.tutorialSkipped, isTrue);
    expect(find.text('LEVEL 01'), findsOneWidget);
    // The offer is gone, because there is nothing left to skip.
    expect(find.byKey(const Key('home-skip-tutorial')), findsNothing);
    // Nothing was faked as cleared on the way past.
    expect(store.allRecords(), isEmpty);
  });
}
