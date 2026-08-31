// Generates every app icon the project ships, for iOS, macOS, Android and web.
//
//     flutter test tool/gen_icon.dart
//
// It runs under `flutter test` because rasterising needs a real Flutter engine,
// and the test harness is the only headless one available. Nothing here asserts
// anything; the "test" is the render.
//
// The icon is composed from the game's own code rather than drawn by hand: the
// backdrop is the gradient from `GrainBackground`, and the cross, dashed radius
// rings and shape are `ShapePainter` with `showGuides` on, exactly as the home
// screen draws its showcase. That is the point of generating it - restyle the
// palette or the geometry and the icon follows, instead of quietly becoming a
// picture of an older version of the game.
//
// Like `tool/gen_sfx.py` and `tool/gen_music.py`, everything is synthesised, so
// there is no third-party art to license.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/core/shape/shape.dart';
import 'package:quadcraft/ui/shape_painter.dart';
import 'package:quadcraft/ui/theme.dart';

/// The face of the game: four leaves, a windmill, four more leaves and a
/// windmill core, the same stack in all four quadrants.
///
/// Four-fold symmetric, which is the strongest emblem the plate can hold and
/// the only symmetry that survives being turned. It is also a shape the dive
/// actually grows rather than a mark invented for the icon — the game's own
/// vocabulary, four layers deep, which is roughly where a target stops being a
/// puzzle you read at a glance and starts being one you have to work out.
final kIconShape = Shape.parse(
  'Lr+Wg+Ly+Wr/Lr+Wg+Ly+Wr/Lr+Wg+Ly+Wr/Lr+Wg+Ly+Wr',
);

/// How much of the canvas the shape spans.
///
/// Every platform masks icons differently, and a maskable icon can lose its
/// whole outer third, so the shape is drawn smaller when something is going to
/// crop it.
const double kInset = 0.72;
const double kMaskableInset = 0.54;

void main() {
  test('renders every app icon', () async {
    for (final target in _targets) {
      final bytes = await _render(target.size, inset: target.inset);
      final file = File(target.path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    }
    // ignore: avoid_print
    print('wrote ${_targets.length} icons');
  });
}

Future<Uint8List> _render(int size, {required double inset}) async {
  final recorder = ui.PictureRecorder();
  final s = size.toDouble();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, s, s));
  final rect = Rect.fromLTWH(0, 0, s, s);

  // --- backdrop: the same gradient the game sits on ------------------------
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        const [Palette.backdropTop, Palette.backdropBottom, Color(0xFF0A1216)],
        const [0.0, 0.55, 1.0],
      ),
  );

  // Brass bloom, lifted from the home screen so the icon glows where the app
  // glows. Centred a little high, as it is there.
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.radial(Offset(s / 2, s * 0.34), s * 0.8, [
        Palette.brass.withValues(alpha: 0.10),
        Palette.brass.withValues(alpha: 0.0),
      ]),
  );

  // --- the shape, cross and rings ------------------------------------------
  final span = s * inset;
  canvas.save();
  canvas.translate((s - span) / 2, (s - span) / 2);
  ShapePainter(
    shape: kIconShape,
    // The cross and the dashed radius rings. They are what make the mark read
    // as a workbench rather than as a logo.
    showGuides: true,
  ).paint(canvas, Size(span, span));
  canvas.restore();

  // --- vignette ------------------------------------------------------------
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.radial(
        rect.center,
        s * 0.78,
        [const Color(0x00000000), const Color(0x59000000)],
        const [0.55, 1.0],
      ),
  );

  // --- grain ---------------------------------------------------------------
  // Deterministic, and skipped when the icon is too small to hold it: at 16 px
  // a grain tile is just noise on top of a shape that already needs every
  // pixel it has.
  if (size >= 96) {
    final rng = math.Random(20260830);
    final grain = Paint()..isAntiAlias = false;
    final dots = (size * size / 90).round();
    for (var i = 0; i < dots; i++) {
      final a = rng.nextDouble() * 0.05;
      grain.color = (rng.nextBool() ? Colors.white : Colors.black).withValues(
        alpha: a,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          rng.nextDouble() * s,
          rng.nextDouble() * s,
          math.max(1, s / 512),
          math.max(1, s / 512),
        ),
        grain,
      );
    }
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

class _Target {
  const _Target(this.path, this.size, {this.inset = kInset});

  final String path;
  final int size;
  final double inset;
}

const _ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _macos = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
const _android = 'android/app/src/main/res';

final _targets = <_Target>[
  // iOS. Sizes are the point size times the scale in each filename.
  const _Target('$_ios/Icon-App-20x20@1x.png', 20),
  const _Target('$_ios/Icon-App-20x20@2x.png', 40),
  const _Target('$_ios/Icon-App-20x20@3x.png', 60),
  const _Target('$_ios/Icon-App-29x29@1x.png', 29),
  const _Target('$_ios/Icon-App-29x29@2x.png', 58),
  const _Target('$_ios/Icon-App-29x29@3x.png', 87),
  const _Target('$_ios/Icon-App-40x40@1x.png', 40),
  const _Target('$_ios/Icon-App-40x40@2x.png', 80),
  const _Target('$_ios/Icon-App-40x40@3x.png', 120),
  const _Target('$_ios/Icon-App-60x60@2x.png', 120),
  const _Target('$_ios/Icon-App-60x60@3x.png', 180),
  const _Target('$_ios/Icon-App-76x76@1x.png', 76),
  const _Target('$_ios/Icon-App-76x76@2x.png', 152),
  const _Target('$_ios/Icon-App-83.5x83.5@2x.png', 167),
  const _Target('$_ios/Icon-App-1024x1024@1x.png', 1024),

  const _Target('$_macos/app_icon_16.png', 16),
  const _Target('$_macos/app_icon_32.png', 32),
  const _Target('$_macos/app_icon_64.png', 64),
  const _Target('$_macos/app_icon_128.png', 128),
  const _Target('$_macos/app_icon_256.png', 256),
  const _Target('$_macos/app_icon_512.png', 512),
  const _Target('$_macos/app_icon_1024.png', 1024),

  const _Target('$_android/mipmap-mdpi/ic_launcher.png', 48),
  const _Target('$_android/mipmap-hdpi/ic_launcher.png', 72),
  const _Target('$_android/mipmap-xhdpi/ic_launcher.png', 96),
  const _Target('$_android/mipmap-xxhdpi/ic_launcher.png', 144),
  const _Target('$_android/mipmap-xxxhdpi/ic_launcher.png', 192),

  const _Target('web/icons/Icon-192.png', 192),
  const _Target('web/icons/Icon-512.png', 512),
  // Maskable icons are cropped to a circle by some launchers, so everything
  // that matters has to survive inside the middle.
  const _Target('web/icons/Icon-maskable-192.png', 192, inset: kMaskableInset),
  const _Target('web/icons/Icon-maskable-512.png', 512, inset: kMaskableInset),
  const _Target('web/favicon.png', 16),
];
