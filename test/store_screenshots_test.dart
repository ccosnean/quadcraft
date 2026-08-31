// Renders store screenshots directly with `flutter test` — no simulator or
// emulator involved. `RenderRepaintBoundary.toImage()` rasterizes each
// screen at the exact pixel dimensions store/devices.yaml asks for.
//
// Each locale gets 5 shots: the home screen, then 4 colorful tutorial
// levels (see _showcaseLevels) solved live via PlayController and captured
// mid-celebration — real gameplay, not a mocked-up board. Screens are
// built directly rather than via real navigation, so 13 locales don't need
// 13 sets of locale-specific button text to match against.
//
// Known toolchain quirk: after the last screenshot is written, this
// process can take a very long time to exit cleanly (a software-rasterizer
// teardown issue independent of app code, font loading, or animations —
// confirmed by bisection). The screenshots themselves are written to disk
// well before that happens, so tool/store/capture_screenshots.sh polls for
// the SCREENSHOTS_COMPLETE marker below and kills the process itself
// rather than waiting on a graceful exit.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/music.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/level/level.dart';
import 'package:quadcraft/core/level/level_catalog.dart';
import 'package:quadcraft/core/shape/shape.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/home/home_screen.dart';
import 'package:quadcraft/features/play/play_controller.dart';
import 'package:quadcraft/features/play/play_screen.dart';
import 'package:quadcraft/l10n/l10n.dart';
import 'package:quadcraft/ui/theme.dart';
import 'package:yaml/yaml.dart';

/// Replays one authored move against a live PlayController — StackMove's
/// shapeId is in the same corner-code format Shape.parse expects (see
/// Shape.id in lib/core/shape/shape.dart), so the blueprint doesn't need to
/// be looked up from the tray.
void _applyMove(PlayController controller, GameMove move) {
  switch (move) {
    case RotateMove():
      controller.rotate();
    case CutMove():
      controller.cut();
    case StackMove(:final shapeId):
      controller.drop(Shape.parse(shapeId));
    case PaintMove(:final color):
      controller.paint(color);
  }
}

class DeviceTarget {
  const DeviceTarget({
    required this.folder,
    required this.width,
    required this.height,
    required this.pixelRatio,
  });

  final String folder;
  final double width;
  final double height;
  final double pixelRatio;
}

/// `flutter test` renders with test-only placeholder fonts by default (no
/// real glyphs, no Material icon glyphs). This registers every font in the
/// asset bundle — including the Material icon font, pulled in automatically
/// by `uses-material-design: true` — so captured screenshots show real text.
Future<void> loadAppFonts() async {
  final manifest = await rootBundle.loadStructuredData<List<dynamic>>(
    'FontManifest.json',
    (value) async => json.decode(value) as List<dynamic>,
  );
  for (final entry in manifest) {
    final map = entry as Map<String, dynamic>;
    final family = map['family'] as String;
    final loader = FontLoader(family);
    for (final font in map['fonts'] as List<dynamic>) {
      final asset = (font as Map<String, dynamic>)['asset'] as String;
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

/// CJK/Arabic/Devanagari glyphs aren't in the bundled SpaceGrotesk/Inter
/// faces — production relies on AppTheme.fallbacks (lib/ui/theme.dart)
/// naming real OS system fonts (e.g. "Noto Sans SC"), which a real device
/// or simulator has installed but this headless test process does not.
/// Registering these files under those exact family names lets the app's
/// existing fontFamilyFallback mechanism find them, with no production
/// code changes. Kept out of pubspec.yaml on purpose — dart:io reads them
/// straight from test/fonts/ so they never ship in a real app build.
Future<void> loadFallbackFonts() async {
  const fonts = {
    'Noto Sans SC': 'test/fonts/NotoSansSC-Regular.ttf',
    'Noto Sans JP': 'test/fonts/NotoSansJP-Regular.ttf',
    'Noto Sans KR': 'test/fonts/NotoSansKR-Regular.ttf',
    'Noto Sans Arabic': 'test/fonts/NotoSansArabic-Regular.ttf',
    'Noto Sans Devanagari': 'test/fonts/NotoSansDevanagari-Regular.ttf',
  };
  for (final entry in fonts.entries) {
    final bytes = File(entry.value).readAsBytesSync();
    final data = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    final loader = FontLoader(entry.key)..addFont(Future.value(data));
    await loader.load();
  }
}

List<DeviceTarget> _loadDevices(String platform) {
  final config =
      loadYaml(File('store/devices.yaml').readAsStringSync()) as YamlMap;
  final entries = config[platform] as YamlList;
  return [
    for (final entry in entries)
      DeviceTarget(
        folder: (entry as YamlMap)['folder'] as String,
        width: (entry['width'] as num).toDouble(),
        height: (entry['height'] as num).toDouble(),
        pixelRatio: (entry['pixel_ratio'] as num).toDouble(),
      ),
  ];
}

/// Store screenshots show these four tutorial levels' Play screen instead
/// of level 1 — all from the Paint / Colour Bank sections, so the board
/// actually has color in it rather than the plain grey opening levels.
/// (lib/core/level/levels.dart: 13 "Fresh Coat" solid red, 19 "Two Tones"
/// red+blue split, 20 "Coloured Core" blue-over-red layering, 21 "Corner
/// Dyes" red+yellow.)
const _showcaseLevels = [13, 19, 20, 21];

/// A fixed, deliberately nicer seed than whatever freshDiveSeed() would
/// roll — shown on the home screen's seed card and used to pick the
/// attract-mode shape, so it's worth it looking good rather than random.
const _showcaseSeed = 314159;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final devices = [..._loadDevices('ios'), ..._loadDevices('android')];

  setUpAll(() async {
    await loadAppFonts();
    await loadFallbackFonts();
  });

  tearDownAll(() {
    // See the file header: the real signal that every screenshot has been
    // written, ahead of this process's own slow-to-arrive exit.
    // ignore: avoid_print
    print('SCREENSHOTS_COMPLETE');
  });

  for (final language in AppLanguage.values) {
    testWidgets('capture store screenshots for ${language.code}', (
      tester,
    ) async {
      final store = MemoryProgressStore()..languageCode = language.code;
      for (var level = 1; level <= 3; level++) {
        store.recordClear(levelNumber: level, moves: 4 + level);
      }
      store.startDive(seed: _showcaseSeed);
      final sounds = SoundBank.silent();
      final music = MusicBed.silent();

      final container = ProviderContainer(
        overrides: [
          progressStoreProvider.overrideWithValue(store),
          soundBankProvider.overrideWithValue(sounds),
          musicBedProvider.overrideWithValue(music),
        ],
      );
      addTearDown(container.dispose);

      // UncontrolledProviderScope (not ProviderScope(overrides:)) so the
      // solved-board shots below can drive PlayController directly via
      // container.read(...), instead of simulating taps through the UI.
      Widget harness(Widget child, GlobalKey key) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(
            wideTracking: language.usesWideTracking,
            useDisplayFace: language.usesDisplayFace,
          ),
          locale: language.locale,
          supportedLocales: AppLanguage.supported,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RepaintBoundary(key: key, child: child),
        ),
      );

      Future<void> pumpFor(Duration total) async {
        const step = Duration(milliseconds: 100);
        for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
          await tester.pump(step);
        }
      }

      // Every level opens on a full-screen "here's the target" overlay
      // (PlayScreen._targetIntro) that the player dismisses with a tap —
      // the interactive board underneath is the more representative shot.
      Future<void> dismissTargetIntro(DeviceTarget device) async {
        // tapAt takes logical coordinates, not the device's physical pixels.
        final logicalWidth = device.width / device.pixelRatio;
        final logicalHeight = device.height / device.pixelRatio;
        await tester.tapAt(Offset(logicalWidth / 2, logicalHeight / 2));
      }

      Future<void> shoot(
        String name,
        Widget screen,
        DeviceTarget device, {
        bool dismissIntro = false,
        LevelRef? solveLevel,
      }) async {
        tester.view.physicalSize = Size(device.width, device.height);
        tester.view.devicePixelRatio = device.pixelRatio;

        final key = GlobalKey();
        await tester.pumpWidget(harness(screen, key));
        await pumpFor(const Duration(milliseconds: 500));
        if (dismissIntro) {
          await dismissTargetIntro(device);
          await pumpFor(const Duration(milliseconds: 1000));
        }

        if (solveLevel != null) {
          final controller = container.read(
            playControllerProvider(solveLevel).notifier,
          );
          for (final move in levelFor(solveLevel).solution) {
            _applyMove(controller, move);
          }
          // Solving fires confetti immediately but the win sheet is on a
          // 750ms timer (play_screen.dart's _celebrate) — pump well under
          // that so the board is captured solved and celebrating, not
          // covered by the modal.
          await pumpFor(const Duration(milliseconds: 400));
        }

        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        // runAsync is required, not optional: toImage()/toByteData() do
        // real async native work, and running them inside the normal fake-
        // async test zone reliably hangs after the first capture in a
        // process (confirmed by bisection) — runAsync steps outside that
        // zone onto the real event loop, which both calls need.
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: device.pixelRatio);
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          image.dispose();
          final dir = Directory(
            'store/screenshots/${language.code}/${device.folder}',
          )..createSync(recursive: true);
          File(
            '${dir.path}/$name.png',
          ).writeAsBytesSync(byteData!.buffer.asUint8List());
        });
      }

      for (final device in devices) {
        await shoot('home', const HomeScreen(), device);
        for (final (i, levelNumber) in _showcaseLevels.indexed) {
          final levelRef = LevelRef.campaign(levelNumber);
          await shoot(
            'play${i + 1}',
            PlayScreen(level: levelRef),
            device,
            dismissIntro: true,
            solveLevel: levelRef,
          );
        }
      }
    });
  }
}
