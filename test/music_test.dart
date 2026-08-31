import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/music.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/settings/settings_screen.dart';
import 'package:quadcraft/ui/theme.dart';

late MemoryProgressStore store;

Widget host(Widget child, {MusicBed? music}) {
  store = MemoryProgressStore();
  return ProviderScope(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      soundBankProvider.overrideWithValue(SoundBank.silent()),
      if (music != null) musicBedProvider.overrideWithValue(music),
    ],
    child: MaterialApp(theme: AppTheme.build(), home: child),
  );
}

void main() {
  group('the bed', () {
    test('plays only when nothing is asking for silence', () {
      final bed = MusicBed.silent();
      bed.start();
      expect(bed.isPlaying, isTrue);

      // Each of the three switches stops it on its own.
      bed.enabled = false;
      expect(bed.isPlaying, isFalse);
      bed.enabled = true;
      expect(bed.isPlaying, isTrue);

      bed.muted = true;
      expect(bed.isPlaying, isFalse);
      bed.muted = false;
      expect(bed.isPlaying, isTrue);

      bed.foreground = false;
      expect(bed.isPlaying, isFalse);
      bed.foreground = true;
      expect(bed.isPlaying, isTrue);
    });

    test('needs every switch back before it resumes', () {
      final bed = MusicBed.silent()..start();
      bed
        ..muted = true
        ..foreground = false;
      expect(bed.isPlaying, isFalse);

      // Coming back to the app does not undo the mute.
      bed.foreground = true;
      expect(bed.isPlaying, isFalse);

      bed.muted = false;
      expect(bed.isPlaying, isTrue);
    });

    testWidgets('turning music off leaves the effects alone', (tester) async {
      final bed = MusicBed.silent()..start();
      await tester.pumpWidget(host(const SettingsScreen(), music: bed));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('music-toggle')));
      await tester.pump();

      expect(bed.isPlaying, isFalse);
      // The one that matters: silencing the bed must not reach the effects.
      expect(store.muted, isFalse);
      expect(
        tester.widget<Switch>(find.byKey(const Key('sound-toggle'))).value,
        isTrue,
      );
    });
  });

  group('losing focus', () {
    // The bug this guards against: treating `inactive` as background made the
    // music fade out and restart every time another window took focus, a menu
    // opened, or a notification arrived.
    test('a window losing focus does not stop the music', () {
      final bed = MusicBed.silent()..start();
      bed.handleLifecycle(AppLifecycleState.inactive);
      expect(bed.isPlaying, isTrue);
      bed.handleLifecycle(AppLifecycleState.resumed);
      expect(bed.isPlaying, isTrue);
    });

    test('actually putting the game away does stop it', () {
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        final bed = MusicBed.silent()..start();
        bed.handleLifecycle(state);
        expect(bed.isPlaying, isFalse, reason: '$state');
        bed.handleLifecycle(AppLifecycleState.resumed);
        expect(bed.isPlaying, isTrue, reason: 'back from $state');
      }
    });

    test('coming back does not override the music setting', () {
      final bed = MusicBed.silent()..start();
      bed.enabled = false;
      bed.handleLifecycle(AppLifecycleState.paused);
      bed.handleLifecycle(AppLifecycleState.resumed);
      expect(bed.isPlaying, isFalse);
    });
  });

  group('the setting', () {
    test('defaults to on, and survives being written', () {
      final store = MemoryProgressStore();
      expect(store.musicEnabled, isTrue);
      store.musicEnabled = false;
      expect(store.musicEnabled, isFalse);
      store.resetAll();
      expect(store.musicEnabled, isTrue, reason: 'a reset gives music back');
    });

    testWidgets('the toggle drives the bed and the store', (tester) async {
      final bed = MusicBed.silent()..start();
      await tester.pumpWidget(host(const SettingsScreen(), music: bed));
      await tester.pump(const Duration(milliseconds: 100));

      expect(store.musicEnabled, isTrue);
      expect(bed.enabled, isTrue);

      await tester.tap(find.byKey(const Key('music-toggle')));
      await tester.pump();
      expect(store.musicEnabled, isFalse);
      expect(bed.enabled, isFalse);

      await tester.tap(find.byKey(const Key('music-toggle')));
      await tester.pump();
      expect(store.musicEnabled, isTrue);
      expect(bed.enabled, isTrue);
    });

    testWidgets('muting everything reads as music off, and gives it back', (
      tester,
    ) async {
      final bed = MusicBed.silent()..start();
      await tester.pumpWidget(host(const SettingsScreen(), music: bed));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('sound-toggle')));
      await tester.pump();

      // The music switch shows off and stops responding, but the stored
      // preference is untouched - unmuting has to restore what was there.
      final toggle = tester.widget<Switch>(
        find.byKey(const Key('music-toggle')),
      );
      expect(toggle.value, isFalse);
      expect(toggle.onChanged, isNull);
      expect(store.musicEnabled, isTrue);
      expect(bed.isPlaying, isFalse);

      await tester.tap(find.byKey(const Key('sound-toggle')));
      await tester.pump();
      expect(
        tester.widget<Switch>(find.byKey(const Key('music-toggle'))).value,
        isTrue,
      );
      expect(bed.isPlaying, isTrue);
    });
  });
}
