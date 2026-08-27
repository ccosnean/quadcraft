import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/shape/shape.dart';
import 'shape_painter.dart';
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

/// Full-screen backdrop: steel gradient, brass bloom, grain, and a soft field
/// of drifting Quadcraft pieces that pop in and fade out like particles.
class GrainBackground extends StatefulWidget {
  const GrainBackground({super.key, required this.child, this.bloom = 1.0});

  final Widget child;

  /// Strength of the brass bloom behind the content.
  final double bloom;

  @override
  State<GrainBackground> createState() => _GrainBackgroundState();
}

class _GrainBackgroundState extends State<GrainBackground>
    with SingleTickerProviderStateMixin {
  static const int _particleCount = 6;

  ui.Image? _grain;
  late final Ticker _ticker;
  late final math.Random _rng;
  late final List<_QuadParticle> _particles;
  Duration _lastTick = Duration.zero;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _rng = math.Random(42);
    _particles = List.generate(
      _particleCount,
      (i) => _QuadParticle.spawn(_rng, stagger: i / _particleCount),
    );

    final ready = GrainTexture.imageIfReady;
    if (ready != null) {
      _grain = ready;
    } else {
      GrainTexture.load().then((image) {
        if (mounted) setState(() => _grain = image);
      });
    }

    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _lastTick = elapsed;

    for (final particle in _particles) {
      particle.advance(dt, _rng);
    }

    // Repaint every frame; the painter is cheap (a handful of small paths).
    _frame++;
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackdropPainter(
        grain: _grain,
        bloom: widget.bloom,
        particles: _particles,
        frame: _frame,
      ),
      isComplex: true,
      willChange: true,
      child: widget.child,
    );
  }
}

/// One ambient shape drifting through the backdrop.
class _QuadParticle {
  _QuadParticle._({
    required this.nx,
    required this.ny,
    required this.vx,
    required this.vy,
    required this.baseSize,
    required this.rotation,
    required this.spin,
    required this.age,
    required this.lifespan,
    required this.form,
    required this.color,
    required this.scaleBreath,
    required this.scalePhase,
  });

  /// Normalized position in the viewport (0..1).
  double nx;
  double ny;

  /// Normalized velocity (fractions of screen per second).
  double vx;
  double vy;

  /// Base radius in logical pixels.
  double baseSize;

  double rotation;
  double spin;

  double age;
  double lifespan;

  QuadForm form;
  QuadColor color;

  /// Subtle continuous scale oscillation amplitude.
  double scaleBreath;
  double scalePhase;

  /// 0 at birth, peaks mid-life, returns to 0 at death.
  double get life {
    final t = (age / lifespan).clamp(0.0, 1.0);
    // Smooth pop-in / fade-out envelope (ease in the middle).
    if (t < 0.2) {
      final u = t / 0.2;
      return Curves.easeOutCubic.transform(u.clamp(0.0, 1.0));
    }
    if (t > 0.75) {
      final u = (1.0 - t) / 0.25;
      return Curves.easeInCubic.transform(u.clamp(0.0, 1.0));
    }
    return 1.0;
  }

  double get displayScale {
    final breath = 1.0 + scaleBreath * math.sin(age * 1.1 + scalePhase);
    return life * breath;
  }

  double get opacity => (0.05 + 0.07 * life).clamp(0.0, 0.12);

  void advance(double dt, math.Random rng) {
    age += dt;
    nx += vx * dt;
    ny += vy * dt;
    rotation += spin * dt;

    // Soft wrap so particles re-enter from the opposite side while alive.
    if (nx < -0.12) nx += 1.24;
    if (nx > 1.12) nx -= 1.24;
    if (ny < -0.12) ny += 1.24;
    if (ny > 1.12) ny -= 1.24;

    if (age >= lifespan) {
      _respawn(rng);
    }
  }

  factory _QuadParticle.spawn(math.Random rng, {double stagger = 0}) {
    final particle = _QuadParticle._(
      nx: 0,
      ny: 0,
      vx: 0,
      vy: 0,
      baseSize: 24,
      rotation: 0,
      spin: 0,
      age: 0,
      lifespan: 1,
      form: QuadForm.circle,
      color: QuadColor.uncolored,
      scaleBreath: 0,
      scalePhase: 0,
    );
    particle._respawn(rng, initialAge: stagger * (6 + rng.nextDouble() * 8));
    return particle;
  }

  void _respawn(math.Random rng, {double? initialAge}) {
    nx = rng.nextDouble();
    ny = rng.nextDouble();
    // Slow drift — mostly vertical with a little lateral sway.
    vx = (rng.nextDouble() - 0.5) * 0.035;
    vy = -0.012 - rng.nextDouble() * 0.028;
    baseSize = 8 + rng.nextDouble() * 10; // 8–18 px
    rotation = rng.nextDouble() * math.pi * 2;
    spin = (rng.nextDouble() - 0.5) * 0.22;
    lifespan = 6.0 + rng.nextDouble() * 8.0;
    age = (initialAge ?? 0).clamp(0.0, lifespan * 0.85);
    form = QuadForm.values[rng.nextInt(QuadForm.values.length)];
    color = _palette[rng.nextInt(_palette.length)];
    scaleBreath = 0.02 + rng.nextDouble() * 0.04;
    scalePhase = rng.nextDouble() * math.pi * 2;
  }

  static const _palette = [
    QuadColor.uncolored,
    QuadColor.red,
    QuadColor.green,
    QuadColor.blue,
    QuadColor.yellow,
    QuadColor.purple,
    QuadColor.cyan,
    QuadColor.orange,
    QuadColor.magenta,
  ];
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    this.grain,
    required this.bloom,
    required this.particles,
    required this.frame,
  });

  final ui.Image? grain;
  final double bloom;
  final List<_QuadParticle> particles;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          const [
            Palette.backdropTop,
            Palette.backdropBottom,
            Color(0xFF0A1216),
          ],
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

    _paintParticles(canvas, size);

    // Vignette keeps the eye on the board and softens particle edges.
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

  void _paintParticles(Canvas canvas, Size size) {
    for (final particle in particles) {
      if (particle.life <= 0.01) continue;

      final center = Offset(
        particle.nx * size.width,
        particle.ny * size.height,
      );
      final radius = particle.baseSize * particle.displayScale;
      if (radius < 2) continue;

      final fillAlpha = particle.opacity;
      final base = Palette.piece(particle.color);
      final fill = Paint()
        ..isAntiAlias = true
        ..color = base.withValues(alpha: fillAlpha);
      final glow = Paint()
        ..isAntiAlias = true
        ..color = Palette.piece(
          particle.color,
        ).withValues(alpha: fillAlpha * 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.18);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.9, radius * 0.03)
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..color = const Color(0xFF0A1116).withValues(alpha: fillAlpha * 0.4);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(particle.rotation);
      // Unit paths live in +x/+y; center the single quadrant on the particle.
      canvas.translate(-radius * 0.45, -radius * 0.45);
      final path = ShapeGeometry.unitPath(
        particle.form,
      ).transform(Matrix4.diagonal3Values(radius, radius, 1).storage);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.grain != grain || old.bloom != bloom || old.frame != frame;
}
