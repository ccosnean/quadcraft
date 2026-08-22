import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/shape/shape.dart';
import '../../ui/theme.dart';

/// Celebration burst played over the board when a level is solved. Particles
/// are plain rounded rects in the game's own palette, simulated on one
/// controller so the whole thing is a single repaint per frame.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.trigger, this.particles = 90});

  /// Changing this value fires a new burst.
  final int trigger;
  final int particles;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late List<_Particle> _particles = _spawn();

  @override
  void initState() {
    super.initState();
    if (widget.trigger > 0) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) {
      _particles = _spawn();
      _controller.forward(from: 0);
    }
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
    ];
    return List.generate(widget.particles, (i) {
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 2.4;
      final speed = 0.55 + rng.nextDouble() * 0.85;
      return _Particle(
        origin: Offset(0.5 + (rng.nextDouble() - 0.5) * 0.22, 0.52),
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        color: rng.nextDouble() < 0.22
            ? Palette.brassBright
            : Palette.piece(palette[rng.nextInt(palette.length)]),
        size: 5 + rng.nextDouble() * 7,
        spin: (rng.nextDouble() - 0.5) * 12,
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
                painter: _ConfettiPainter(particles: _particles, t: _controller.value),
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
    required this.size,
    required this.spin,
    required this.delay,
  });

  /// Fractional position within the paint box.
  final Offset origin;
  final Offset velocity;
  final Color color;
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
    final paint = Paint();
    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final fade = local > 0.72 ? 1 - (local - 0.72) / 0.28 : 1.0;
      if (fade <= 0) continue;

      final dx = p.origin.dx * size.width + p.velocity.dx * local * size.width * 0.9;
      final dy = p.origin.dy * size.height +
          (p.velocity.dy * local + gravity * local * local * 0.75) * size.height * 0.9;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.spin * local);
      paint.color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t || old.particles != particles;
}
