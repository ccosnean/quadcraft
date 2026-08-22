import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/shape/shape.dart';
import 'theme.dart';

/// Geometry helpers shared by every shape drawing in the game.
///
/// All forms are authored once in a unit quadrant that occupies the +x/+y
/// octant with an outer radius of 1, then reused by rotating the canvas. That
/// keeps painting allocation-free on the hot path.
abstract final class ShapeGeometry {
  /// Fraction of the radius kept clear along the quadrant seams.
  static const double seam = 0.055;

  /// Each stacked layer is drawn this much smaller than the one below it.
  static const double layerFalloff = 0.72;

  /// Radius as a fraction of half the widget size. Leaves room for square and
  /// windmill quadrants, whose corners reach past the circle's radius.
  static const double radiusFactor = 0.70;

  static final Map<QuadForm, Path> _unit = {
    for (final form in QuadForm.values) form: _buildUnit(form),
  };

  static Path unitPath(QuadForm form) => _unit[form]!;

  /// Clockwise canvas rotation that moves the canonical quadrant into place.
  static double angleOf(Corner corner) => switch (corner) {
        Corner.br => 0,
        Corner.bl => math.pi / 2,
        Corner.tl => math.pi,
        Corner.tr => 3 * math.pi / 2,
      };

  static Path _buildUnit(QuadForm form) {
    // Forms live in the +x/+y unit quadrant. Square/star/windmill are inset by
    // [seam] on every edge so neighbours never touch. Circles are special: the
    // arc must be centered on the shared plate origin (0,0) so four rotated
    // quarters form one smooth ring — centering on the inset corner was the
    // source of the faceted "weird lines" on the outer rim.
    const span = 1 - seam;
    Offset at(double u, double v) => Offset(seam + u * span, seam + v * span);

    switch (form) {
      case QuadForm.circle:
        // Quarter disk around the shared plate origin so four rotated copies
        // form one smooth ring. Seam only opens the radial edges.
        return Path()
          ..moveTo(seam, seam)
          ..lineTo(seam, 0)
          ..lineTo(1, 0)
          ..arcTo(const Rect.fromLTRB(-1, -1, 1, 1), 0, math.pi / 2, false)
          ..lineTo(0, seam)
          ..close();
      case QuadForm.square:
        return Path()
          ..moveTo(at(0, 0).dx, at(0, 0).dy)
          ..lineTo(at(1, 0).dx, at(1, 0).dy)
          ..lineTo(at(1, 1).dx, at(1, 1).dy)
          ..lineTo(at(0, 1).dx, at(0, 1).dy)
          ..close();
      case QuadForm.star:
        return Path()
          ..moveTo(at(0, 0).dx, at(0, 0).dy)
          ..lineTo(at(1, 0).dx, at(1, 0).dy)
          ..lineTo(at(0.42, 0.42).dx, at(0.42, 0.42).dy)
          ..lineTo(at(0, 1).dx, at(0, 1).dy)
          ..close();
      case QuadForm.windmill:
        return Path()
          ..moveTo(at(0, 0).dx, at(0, 0).dy)
          ..lineTo(at(1, 0).dx, at(1, 0).dy)
          ..lineTo(at(1, 0.52).dx, at(1, 0.52).dy)
          ..lineTo(at(0, 1).dx, at(0, 1).dy)
          ..close();
    }
  }

  /// Fill gradient for a piece, lit consistently from the top-left of the
  /// board regardless of which quadrant it sits in.
  static ui.Shader shaderFor(QuadColor color, Corner corner) {
    final key = (color, corner);
    return _shaders[key] ??= _buildShader(color, corner);
  }

  static final Map<(QuadColor, Corner), ui.Shader> _shaders = {};

  static ui.Shader _buildShader(QuadColor color, Corner corner) {
    // Global light travels along (1, 1); undo the quadrant rotation so the
    // highlight always lands on the board's upper-left side.
    final a = -angleOf(corner);
    final dx = math.cos(a) * 0.7071 - math.sin(a) * 0.7071;
    final dy = math.sin(a) * 0.7071 + math.cos(a) * 0.7071;
    return ui.Gradient.linear(
      Offset(-dx * 1.1, -dy * 1.1),
      Offset(dx * 1.1, dy * 1.1),
      [Palette.pieceSheen(color), Palette.piece(color), Palette.pieceShade(color)],
      const [0.0, 0.45, 1.0],
    );
  }
}

/// Draws a [Shape]: quadrant stacks plus optional board guides.
class ShapePainter extends CustomPainter {
  ShapePainter({
    required this.shape,
    this.showGuides = false,
    this.ghostEmpty = false,
    this.opacity = 1.0,
    this.emphasis = 0.0,
    this.emphasisColor,
    this.rejectedCorners = const <Corner>{},
    this.reject = 0.0,
  });

  final Shape shape;

  /// Draw the sunken plate markings (dashed radius, seams, quadrant ghosts).
  final bool showGuides;

  /// Outline empty quadrants to hint where pieces can land.
  final bool ghostEmpty;

  final double opacity;

  /// 0..1 glow used for drop targeting and win celebration.
  final double emphasis;
  final Color? emphasisColor;

  /// Quadrants that just refused a drop, flashed via [reject].
  final Set<Corner> rejectedCorners;
  final double reject;

  static final Paint _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true
    ..color = const Color(0xFF0A1116);

  @override
  void paint(Canvas canvas, Size size) {
    final half = size.shortestSide / 2;
    final radius = half * ShapeGeometry.radiusFactor;
    final center = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);

    if (showGuides) {
      _paintGuides(canvas, radius);
    }

    for (final corner in Corner.values) {
      final quadrant = shape[corner];
      canvas.save();
      canvas.rotate(ShapeGeometry.angleOf(corner));

      if (quadrant.isEmpty) {
        if (ghostEmpty) _paintGhost(canvas, radius);
      } else {
        for (var i = 0; i < quadrant.layers.length; i++) {
          _paintPiece(canvas, quadrant.layers[i], corner, radius, i);
        }
      }

      if (reject > 0 && rejectedCorners.contains(corner)) {
        _paintReject(canvas, radius);
      }
      canvas.restore();
    }

    if (emphasis > 0) {
      _paintEmphasis(canvas, radius);
    }

    canvas.restore();
  }

  void _paintPiece(Canvas canvas, LayerPiece piece, Corner corner, double radius, int layer) {
    final scale = radius * math.pow(ShapeGeometry.layerFalloff, layer).toDouble();
    canvas.save();
    canvas.scale(scale);

    final path = ShapeGeometry.unitPath(piece.form);
    final fill = Paint()
      ..shader = ShapeGeometry.shaderFor(piece.color, corner)
      ..isAntiAlias = true;
    if (opacity < 1) {
      canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: opacity));
    }
    canvas.drawPath(path, fill);

    // Outline width is expressed in unit space, so it thickens with the piece
    // and keeps deep layers legible.
    canvas.drawPath(
      path,
      _outline
        ..strokeWidth = 0.055
        ..color = const Color(0xFF0A1116).withValues(alpha: 0.55 * opacity),
    );

    if (opacity < 1) canvas.restore();
    canvas.restore();
  }

  void _paintGuides(Canvas canvas, double radius) {
    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Palette.hairline.withValues(alpha: 0.7);

    // Seam cross.
    final reach = radius * 1.42;
    canvas.drawLine(Offset(-reach, 0), Offset(reach, 0), hairline);
    canvas.drawLine(Offset(0, -reach), Offset(0, reach), hairline);

    _dashedCircle(canvas, radius, hairline..color = Palette.hairlineBright.withValues(alpha: 0.5));
    _dashedCircle(
      canvas,
      radius * ShapeGeometry.layerFalloff,
      hairline..color = Palette.hairline.withValues(alpha: 0.45),
    );
  }

  void _dashedCircle(Canvas canvas, double radius, Paint paint) {
    const dashes = 48;
    const sweep = math.pi * 2 / dashes;
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.5, false, paint);
    }
  }

  void _paintGhost(Canvas canvas, double radius) {
    canvas.save();
    canvas.scale(radius);
    canvas.drawPath(
      ShapeGeometry.unitPath(QuadForm.circle),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.03
        ..color = Palette.hairlineBright.withValues(alpha: 0.5),
    );
    canvas.restore();
  }

  void _paintReject(Canvas canvas, double radius) {
    canvas.save();
    canvas.scale(radius);
    canvas.drawPath(
      ShapeGeometry.unitPath(QuadForm.square),
      Paint()..color = Palette.danger.withValues(alpha: 0.28 * reject),
    );
    canvas.restore();
  }

  void _paintEmphasis(Canvas canvas, double radius) {
    final color = emphasisColor ?? Palette.brass;
    canvas.drawCircle(
      Offset.zero,
      radius * (1.06 + 0.12 * emphasis),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + 2.5 * emphasis
        ..color = color.withValues(alpha: 0.55 * emphasis)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 10 * emphasis),
    );
  }

  @override
  bool shouldRepaint(ShapePainter old) =>
      old.shape.id != shape.id ||
      old.showGuides != showGuides ||
      old.ghostEmpty != ghostEmpty ||
      old.opacity != opacity ||
      old.emphasis != emphasis ||
      old.emphasisColor != emphasisColor ||
      old.reject != reject ||
      !setEquals(old.rejectedCorners, rejectedCorners);
}

/// A plain, non-interactive rendering of a shape.
class ShapeView extends StatelessWidget {
  const ShapeView({
    super.key,
    required this.shape,
    this.size,
    this.showGuides = false,
    this.ghostEmpty = false,
    this.opacity = 1.0,
    this.emphasis = 0.0,
    this.emphasisColor,
    this.rejectedCorners = const <Corner>{},
    this.reject = 0.0,
  });

  final Shape shape;
  final double? size;
  final bool showGuides;
  final bool ghostEmpty;
  final double opacity;
  final double emphasis;
  final Color? emphasisColor;
  final Set<Corner> rejectedCorners;
  final double reject;

  @override
  Widget build(BuildContext context) {
    final painter = ShapePainter(
      shape: shape,
      showGuides: showGuides,
      ghostEmpty: ghostEmpty,
      opacity: opacity,
      emphasis: emphasis,
      emphasisColor: emphasisColor,
      rejectedCorners: rejectedCorners,
      reject: reject,
    );
    if (size != null) {
      return CustomPaint(size: Size.square(size!), painter: painter);
    }
    return CustomPaint(painter: painter, child: const SizedBox.expand());
  }
}
