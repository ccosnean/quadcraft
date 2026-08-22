import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/shape/shape.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'play_controller.dart';

/// The main board: plate chrome, the live shape, and every board animation
/// (turn, cut, drop pop, paint ripple, refusal shake, solve glow).
class BoardStage extends StatefulWidget {
  const BoardStage({
    super.key,
    required this.shape,
    required this.size,
    required this.effect,
    required this.effectId,
    this.dropGlow = 0.0,
    this.dropGlowColor,
  });

  final Shape shape;
  final double size;

  /// Latest board effect; replayed whenever [effectId] changes.
  final BoardEffect? effect;
  final int effectId;

  final double dropGlow;
  final Color? dropGlowColor;

  @override
  State<BoardStage> createState() => _BoardStageState();
}

class _BoardStageState extends State<BoardStage> with TickerProviderStateMixin {
  late final _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final _cut = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  late final _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final _solve = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  Shape _cutTop = Shape.empty;
  Shape _cutBottom = Shape.empty;
  QuadColor _rippleColor = QuadColor.uncolored;
  Set<Corner> _rejected = const {};

  @override
  void didUpdateWidget(BoardStage old) {
    super.didUpdateWidget(old);
    if (old.effectId != widget.effectId) _playEffect(widget.effect);
  }

  void _playEffect(BoardEffect? effect) {
    switch (effect) {
      case RotatedEffect():
        _turn.forward(from: 0);
      case CutEffect(:final top, :final bottom):
        _cutTop = top;
        _cutBottom = bottom;
        _cut.forward(from: 0);
      case StackedEffect():
        _pop.forward(from: 0);
      case PaintedEffect(:final color):
        _rippleColor = color;
        _ripple.forward(from: 0);
      case RejectedEffect(:final corners):
        _rejected = corners;
        _shake.forward(from: 0);
      case SolvedEffect():
        _solve.forward(from: 0);
      case ResetEffect():
        _pop.forward(from: 0);
      case null:
        break;
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    _cut.dispose();
    _pop.dispose();
    _ripple.dispose();
    _shake.dispose();
    _solve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return AnimatedBuilder(
      animation: Listenable.merge([_turn, _cut, _pop, _ripple, _shake, _solve]),
      builder: (context, _) {
        final turn = _turn.isAnimating
            ? -math.pi / 2 * (1 - Curves.easeOutCubic.transform(_turn.value))
            : 0.0;
        final pop = _pop.isAnimating
            ? 1 + 0.055 * (1 - Curves.easeOutBack.transform(_pop.value))
            : 1.0;
        final shake = _shake.isAnimating
            ? math.sin(_shake.value * math.pi * 5) * 9 * (1 - _shake.value)
            : 0.0;
        final reject = _shake.isAnimating ? 1 - _shake.value : 0.0;
        final solvePulse = _solve.isAnimating
            ? math.sin(Curves.easeOut.transform(_solve.value) * math.pi)
            : 0.0;
        final glow = math.max(widget.dropGlow, solvePulse);

        return Transform.translate(
          offset: Offset(shake, 0),
          child: Transform.scale(
            scale: pop,
            child: Plate(
              glow: glow,
              glowColor: solvePulse > widget.dropGlow ? Palette.brassBright : widget.dropGlowColor,
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: turn,
                      child: ShapeView(
                        shape: widget.shape,
                        size: size,
                        showGuides: true,
                        ghostEmpty: true,
                        emphasis: solvePulse,
                        emphasisColor: Palette.brassBright,
                        rejectedCorners: _rejected,
                        reject: reject,
                      ),
                    ),
                    if (_cut.isAnimating) ..._cutGhosts(size),
                    if (_ripple.isAnimating)
                      CustomPaint(
                        size: Size.square(size),
                        painter: _RipplePainter(
                          progress: _ripple.value,
                          color: Palette.piece(_rippleColor),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The two halves drift apart and fade after a cut, so the plate emptying
  /// reads as a physical split rather than a state jump.
  List<Widget> _cutGhosts(double size) {
    final t = Curves.easeOutCubic.transform(_cut.value);
    final travel = size * 0.22 * t;
    final fade = (1 - t).clamp(0.0, 1.0);
    return [
      Transform.translate(
        offset: Offset(0, -travel),
        child: ShapeView(shape: _cutTop, size: size, opacity: fade),
      ),
      Transform.translate(
        offset: Offset(0, travel),
        child: ShapeView(shape: _cutBottom, size: size, opacity: fade),
      ),
      IgnorePointer(
        child: CustomPaint(
          size: Size.square(size),
          painter: _CutLinePainter(progress: _cut.value),
        ),
      ),
    ];
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(progress);
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.72 * t;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * (1 - t) + 1
        ..color = color.withValues(alpha: 0.55 * (1 - t)),
    );
    canvas.drawCircle(
      center,
      radius * 0.94,
      Paint()..color = color.withValues(alpha: 0.14 * (1 - t)),
    );
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress || old.color != color;
}

/// Bright seam that sweeps across the plate at the moment of the cut.
class _CutLinePainter extends CustomPainter {
  _CutLinePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final sweep = Curves.easeOutExpo.transform(math.min(1, progress * 2.2));
    final fade = (1 - math.max(0, progress * 1.6 - 0.6)).clamp(0.0, 1.0);
    final y = size.height / 2;
    final half = size.width * 0.5 * sweep;
    canvas.drawLine(
      Offset(size.width / 2 - half, y),
      Offset(size.width / 2 + half, y),
      Paint()
        ..strokeWidth = 2.4
        ..color = Palette.brassBright.withValues(alpha: 0.9 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(_CutLinePainter old) => old.progress != progress;
}
