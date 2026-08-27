import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/shape/shape.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';

/// Celebration burst played over the board when a level is solved.
///
/// Each particle is a single quadrant silhouette in a random piece colour —
/// never a combined 2×2 plate.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.trigger, this.particles = 72});

  /// Changing this value fires a new burst.
  final int trigger;
  final int particles;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late List<_Particle> _particles = _spawn();

  @override
  void initState() {
    super.initState();
    if (widget.trigger > 0) _fire();
  }

  @override
  void didUpdateWidget(ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _fire();
  }

  void _fire() {
    if (widget.particles <= 0) {
      _controller.stop();
      _particles = const [];
      return;
    }
    _particles = _spawn();
    _controller.forward(from: 0);
  }

  List<_Particle> _spawn() {
    final rng = math.Random(widget.trigger * 7919 + 13);
    const palette = [
      QuadColor.red,
      QuadColor.green,
      QuadColor.blue,
      QuadColor.yellow,
      QuadColor.purple,
      QuadColor.cyan,
      QuadColor.orange,
      QuadColor.magenta,
    ];
    return List.generate(widget.particles, (i) {
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 2.4;
      final speed = 0.55 + rng.nextDouble() * 0.85;
      return _Particle(
        origin: Offset(0.5 + (rng.nextDouble() - 0.5) * 0.22, 0.52),
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        color: rng.nextDouble() < 0.18
            ? Palette.brassBright
            : Palette.piece(palette[rng.nextInt(palette.length)]),
        form: QuadForm.values[rng.nextInt(QuadForm.values.length)],
        size: 7 + rng.nextDouble() * 9,
        spin: (rng.nextDouble() - 0.5) * 10,
        delay: rng.nextDouble() * 0.18,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _controller.isAnimating
            ? CustomPaint(
                painter: _ConfettiPainter(
                  particles: _particles,
                  t: _controller.value,
                ),
                child: const SizedBox.expand(),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.origin,
    required this.velocity,
    required this.color,
    required this.form,
    required this.size,
    required this.spin,
    required this.delay,
  });

  /// Fractional position within the paint box.
  final Offset origin;
  final Offset velocity;
  final Color color;
  final QuadForm form;
  final double size;
  final double spin;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.t});

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 1.35;
    final fill = Paint()..isAntiAlias = true;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final fade = local > 0.72 ? 1 - (local - 0.72) / 0.28 : 1.0;
      if (fade <= 0) continue;

      final dx =
          p.origin.dx * size.width + p.velocity.dx * local * size.width * 0.9;
      final dy =
          p.origin.dy * size.height +
          (p.velocity.dy * local + gravity * local * local * 0.75) *
              size.height *
              0.9;

      final alpha = fade.clamp(0.0, 1.0);
      fill.color = p.color.withValues(alpha: alpha);
      stroke
        ..color = const Color(0xFF0A1116).withValues(alpha: alpha * 0.35)
        ..strokeWidth = math.max(0.7, p.size * 0.04);

      // Unit paths live in the +x/+y quadrant; nudge so the piece is centered
      // on the particle instead of looking like a corner of a full plate.
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.spin * local);
      canvas.translate(-p.size * 0.45, -p.size * 0.45);

      final path = ShapeGeometry.unitPath(
        p.form,
      ).transform(Matrix4.diagonal3Values(p.size, p.size, 1).storage);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.t != t || old.particles != particles;
}
