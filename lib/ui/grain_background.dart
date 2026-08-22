import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Lazily built, process-wide grain tile. Generated in code so there is no
/// image asset to ship and no decode cost beyond the first frame.
abstract final class GrainTexture {
  static const int _size = 128;
  static ui.Image? _image;
  static Future<ui.Image>? _pending;

  static ui.Image? get imageIfReady => _image;

  static Future<ui.Image> load() {
    final ready = _image;
    if (ready != null) return Future.value(ready);
    return _pending ??= _generate().then((image) {
      _image = image;
      return image;
    });
  }

  static Future<ui.Image> _generate() {
    final rng = math.Random(7);
    final pixels = Uint8List(_size * _size * 4);
    for (var i = 0; i < _size * _size; i++) {
      final alpha = rng.nextInt(30);
      // Premultiplied: white speckles carry colour equal to alpha, dark
      // speckles carry none.
      final light = rng.nextBool();
      final value = light ? alpha : 0;
      final o = i * 4;
      pixels[o] = value;
      pixels[o + 1] = value;
      pixels[o + 2] = value;
      pixels[o + 3] = alpha;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      _size,
      _size,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}

/// Full-screen backdrop: vertical steel gradient, a warm brass bloom near the
/// top, a soft vignette and a fine grain overlay.
class GrainBackground extends StatefulWidget {
  const GrainBackground({super.key, required this.child, this.bloom = 1.0});

  final Widget child;

  /// Strength of the brass bloom behind the content.
  final double bloom;

  @override
  State<GrainBackground> createState() => _GrainBackgroundState();
}

class _GrainBackgroundState extends State<GrainBackground> {
  ui.Image? _grain;

  @override
  void initState() {
    super.initState();
    final ready = GrainTexture.imageIfReady;
    if (ready != null) {
      _grain = ready;
    } else {
      GrainTexture.load().then((image) {
        if (mounted) setState(() => _grain = image);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackdropPainter(grain: _grain, bloom: widget.bloom),
      child: widget.child,
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({this.grain, required this.bloom});

  final ui.Image? grain;
  final double bloom;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

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

    if (bloom > 0) {
      final focus = Offset(size.width / 2, size.height * 0.3);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(focus, size.width * 0.85, [
            Palette.brass.withValues(alpha: 0.055 * bloom),
            Palette.brass.withValues(alpha: 0.0),
          ]),
      );
    }

    // Vignette keeps the eye on the board.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          size.longestSide * 0.72,
          [const Color(0x00000000), const Color(0x66000000)],
          const [0.55, 1.0],
        ),
    );

    final texture = grain;
    if (texture != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.ImageShader(
            texture,
            TileMode.repeated,
            TileMode.repeated,
            Matrix4.identity().storage,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.grain != grain || old.bloom != bloom;
}
