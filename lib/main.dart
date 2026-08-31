import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app_providers.dart';
import 'audio/music.dart';
import 'audio/sfx.dart';
import 'data/progress_store.dart';
import 'ui/grain_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF0A1216),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final store = await ProgressStore.open();
  final sounds = await SoundBank.load();
  final music = await MusicBed.load();
  // Warm the grain tile so the first screen paints complete.
  await GrainTexture.load();

  // Settled before the first note so the bed never blurts out a second of
  // music at someone who turned it off last time.
  music
    ..muted = store.muted
    ..enabled = store.musicEnabled
    ..start();

  // Hand the foreground back and forth. Held for the life of the app, so it
  // is never disposed. The policy lives on the bed, where it can be tested.
  AppLifecycleListener(onStateChange: music.handleLifecycle);

  runApp(
    ProviderScope(
      overrides: [
        progressStoreProvider.overrideWithValue(store),
        soundBankProvider.overrideWithValue(sounds),
        musicBedProvider.overrideWithValue(music),
      ],
      child: const QuadcraftApp(),
    ),
  );
}
