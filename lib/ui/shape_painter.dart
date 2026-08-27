import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/shape/shape.dart';
import 'theme.dart';

/// Geometry helpers shared by every shape drawing in the game.
///
/// All forms are authored once in a unit quadrant that occupies the +x/+y
/// octant with an outer radius of 1, then reused by rotating the canvas. That
/// keeps painting allocation-free on the hot path.
///
/// Every form meets the shared plate origin and the two radial axes, so four
/// matching quarters combine into one continuous silhouette (disk, square,
/// star, windmill, shuriken, flower) with only a thin outline between pieces.
abstract final class ShapeGeometry {
  /// Radius as a fraction of half the widget size. Leaves room for square and
  /// windmill quadrants, whose corners reach past the circle's radius.
  static const double radiusFactor = 0.70;

  /// Each stacked layer is drawn this much smaller than the one below it.
  /// Bottom (index 0) = outermost; top = innermost.
  static const double layerFalloff = 0.72;

  /// Outline width in unit space (path is scaled by piece radius).
  static const double outlineWidth = 0.045;

  /// Slight oversize so abutting fills hide the guide crosshair under AA.
  static const double fillBleed = 1.01;

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
    const seam = 0.02;
    // Forms live in the +x/+y unit quadrant and meet the shared plate origin
    // so four matching quarters combine into one continuous silhouette.
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
          ..moveTo(0, 0)
          ..lineTo(1, 0)
          ..lineTo(1, 1)
          ..lineTo(0, 1)
          ..close();
      case QuadForm.star:
        // Shapez-style bite: outer arms on the axes, notch toward the rim.
        return Path()
          ..moveTo(0, 0)
          ..lineTo(1, 0)
          ..lineTo(0.42, 0.42)
          ..lineTo(0, 1)
          ..close();
      case QuadForm.windmill:
        return Path()
          ..moveTo(0, 0)
          ..lineTo(1, 0)
          ..lineTo(1, 0.52)
          ..lineTo(0, 1)
          ..close();
      case QuadForm.pike:
        // Blade to the outer corner. Four copies make a four-point shuriken.
        return Path()
          ..moveTo(0, 0)
          ..lineTo(0.46, 0)
          ..lineTo(1, 1)
          ..lineTo(0, 0.46)
          ..close();
      case QuadForm.leaf:
        // Rounded petal to the outer corner. Four copies make a clover.
        return Path()
          ..moveTo(0, 0)
          ..lineTo(0.62, 0)
          ..quadraticBezierTo(1.08, 0.22, 1, 1)
          ..quadraticBezierTo(0.22, 1.08, 0, 0.62)
          ..close();
    }
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

  static final Paint _fill = Paint()..isAntiAlias = true;

  static final Paint _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.miter
    ..strokeMiterLimit = 4
    ..strokeCap = StrokeCap.butt
    ..isAntiAlias = true;

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

    // Bottom → top by layer. Bottom layers are largest; each layer above is
    // scaled by [layerFalloff] so the stack reads as concentric rings.
    // Within a layer: all fills, then all outlines, so neighbours share an
    // even seam and upper fills cover lower outlines in the centre.
    final depth = shape.depth;
    for (var layer = 0; layer < depth; layer++) {
      final scale =
          radius * math.pow(ShapeGeometry.layerFalloff, layer).toDouble();
      _forLayer(canvas, layer, (piece, corner) {
        _paintFill(canvas, piece, scale);
      });
      _forLayer(canvas, layer, (piece, corner) {
        _paintOutline(canvas, piece.form, scale, layer);
      });
    }

    for (final corner in Corner.values) {
      canvas.save();
      canvas.rotate(ShapeGeometry.angleOf(corner));
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

  void _forLayer(
    Canvas canvas,
    int layer,
    void Function(LayerPiece piece, Corner corner) paint,
  ) {
    for (final corner in Corner.values) {
      final quadrant = shape[corner];
      if (layer >= quadrant.layers.length) continue;
      canvas.save();
      canvas.rotate(ShapeGeometry.angleOf(corner));
      paint(quadrant.layers[layer], corner);
      canvas.restore();
    }
  }

  void _paintFill(Canvas canvas, LayerPiece piece, double scale) {
    canvas.save();
    canvas.scale(scale * ShapeGeometry.fillBleed);
    _fill.color = Palette.piece(piece.color).withValues(alpha: opacity);
    canvas.drawPath(ShapeGeometry.unitPath(piece.form), _fill);
    canvas.restore();
  }

  void _paintOutline(Canvas canvas, QuadForm form, double scale, int layer) {
    canvas.save();
    canvas.scale(scale);

    // Use the fixed outline width in logical pixels, independent of scale.
    final outlineWidth = ShapeGeometry.outlineWidth;

    if (form == QuadForm.circle) {
      canvas.drawLine(
        Offset(1, 0),
        Offset(0, 0),
        _outline
          ..strokeWidth = outlineWidth
          ..color = const Color(0xFF0A1116),
      );
      canvas.drawLine(
        Offset(0, 0),
        Offset(0, 1),
        _outline
          ..strokeWidth = outlineWidth
          ..color = const Color(0xFF0A1116),
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 1),
        0,
        math.pi / 2,
        false,
        _outline
          ..strokeWidth = outlineWidth
          ..color = const Color(0xFF0A1116),
      );
    } else {
      canvas.drawPath(
        ShapeGeometry.unitPath(form),
        _outline
          ..strokeWidth = outlineWidth
          ..color = const Color(0xFF0A1116),
      );
    }

    canvas.restore();
  }

  void _paintGuides(Canvas canvas, double radius) {
    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Palette.hairline.withValues(alpha: 0.7);

    // Seam cross.
    final reach = radius * 1.42;
    canvas.drawLine(Offset(-reach, 0), Offset(reach, 0), hairline);
    canvas.drawLine(Offset(0, -reach), Offset(0, reach), hairline);

    _dashedCircle(
      canvas,
      radius,
      hairline..color = Palette.hairlineBright.withValues(alpha: 0.5),
    );
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
