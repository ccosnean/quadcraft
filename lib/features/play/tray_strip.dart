import 'package:flutter/material.dart';

import '../../core/shape/shape.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// What a tray item hands to the board when dropped.
sealed class TrayPayload {
  const TrayPayload();
}

class ShapePayload extends TrayPayload {
  const ShapePayload(this.shape);

  final Shape shape;
}

class ColorPayload extends TrayPayload {
  const ColorPayload(this.color);

  final QuadColor color;
}

/// Bottom tray: reusable blueprints and available paints, sized and positioned
/// for a thumb.
class TrayStrip extends StatelessWidget {
  const TrayStrip({
    super.key,
    required this.shapes,
    required this.colors,
    required this.onPlaceShape,
    required this.onPaint,
    required this.onDragStart,
    this.blockedShapeIds = const <String>{},
  });

  final List<Shape> shapes;
  final List<QuadColor> colors;
  final ValueChanged<Shape> onPlaceShape;
  final ValueChanged<QuadColor> onPaint;
  final VoidCallback onDragStart;

  /// Blueprints that cannot currently be placed, shown dimmed.
  final Set<String> blockedShapeIds;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Overline('Blueprints'),
              const Spacer(),
              Overline('drag or tap', color: Palette.inkFaint.withValues(alpha: 0.8)),
            ],
          ),
          const SizedBox(height: 10),
          if (shapes.isEmpty)
            const _EmptyTrayHint()
          else
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: shapes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final shape = shapes[index];
                  return _ChipEntrance(
                    key: ValueKey('bp-${shape.id}'),
                    child: _ShapeChip(
                      shape: shape,
                      blocked: blockedShapeIds.contains(shape.id),
                      onTap: () => onPlaceShape(shape),
                      onDragStart: onDragStart,
                    ),
                  );
                },
              ),
            ),
          if (colors.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Overline('Paint'),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: colors.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _ChipEntrance(
                  key: ValueKey('paint-${colors[index].name}'),
                  child: _ColorChip(
                    color: colors[index],
                    onTap: () => onPaint(colors[index]),
                    onDragStart: onDragStart,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyTrayHint extends StatelessWidget {
  const _EmptyTrayHint();

  @override
  Widget build(BuildContext context) => Container(
        height: 78,
        alignment: Alignment.center,
        child: Text(
          'No blueprints. Work with what is on the plate.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}

class _ShapeChip extends StatelessWidget {
  const _ShapeChip({
    required this.shape,
    required this.blocked,
    required this.onTap,
    required this.onDragStart,
  });

  final Shape shape;
  final bool blocked;
  final VoidCallback onTap;
  final VoidCallback onDragStart;

  @override
  Widget build(BuildContext context) {
    final well = Opacity(
      opacity: blocked ? 0.4 : 1,
      child: AspectRatio(
        aspectRatio: 1,
        child: Plate(
          radius: 18,
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.biggest.shortestSide;
              return ShapeView(shape: shape, size: side);
            },
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Blueprint ${shape.id}',
      child: SizedBox(
        width: 78,
        child: Draggable<TrayPayload>(
          data: ShapePayload(shape),
          onDragStarted: onDragStart,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _DragGhost(
            child: SizedBox.square(
              dimension: 112,
              child: ShapeView(shape: shape, size: 112),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: well),
          child: GestureDetector(onTap: onTap, child: well),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({required this.color, required this.onTap, required this.onDragStart});

  final QuadColor color;
  final VoidCallback onTap;
  final VoidCallback onDragStart;

  @override
  Widget build(BuildContext context) {
    final swatch = _Swatch(color: color, diameter: 48);
    return Semantics(
      button: true,
      label: '${Palette.label(color)} paint',
      child: Draggable<TrayPayload>(
        data: ColorPayload(color),
        onDragStarted: onDragStart,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: _DragGhost(child: _Swatch(color: color, diameter: 76)),
        childWhenDragging: Opacity(opacity: 0.25, child: swatch),
        child: GestureDetector(onTap: onTap, child: swatch),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.diameter});

  final QuadColor color;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.0,
          colors: [Palette.pieceSheen(color), Palette.piece(color), Palette.pieceShade(color)],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: Colors.black.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Palette.piece(color).withValues(alpha: 0.35),
            blurRadius: diameter * 0.28,
            offset: Offset(0, diameter * 0.08),
          ),
        ],
      ),
    );
  }
}

/// What the finger carries around: lifted, glowing, slightly above the touch.
class _DragGhost extends StatelessWidget {
  const _DragGhost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-52, -68),
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Palette.brass.withValues(alpha: 0.25),
                blurRadius: 28,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Scale-in used when a blueprint appears (level load or a fresh cut).
class _ChipEntrance extends StatefulWidget {
  const _ChipEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<_ChipEntrance> createState() => _ChipEntranceState();
}

class _ChipEntranceState extends State<_ChipEntrance> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    return ScaleTransition(
      scale: Tween(begin: 0.7, end: 1.0).animate(curve),
      child: FadeTransition(opacity: _controller, child: widget.child),
    );
  }
}
