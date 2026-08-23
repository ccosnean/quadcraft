import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../core/shape/shape.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Tap callbacks include the chip's global bounds so the play screen can fly
/// a ghost from the tray to the plate.
typedef TrayShapeTap = void Function(Shape shape, Rect globalOrigin);
typedef TrayColorTap = void Function(QuadColor color, Rect globalOrigin);

/// Bottom tray: reusable blueprints and paints. Tap places; the list scrolls
/// freely with no drag competing for the gesture.
class TrayStrip extends StatelessWidget {
  const TrayStrip({
    super.key,
    required this.shapes,
    required this.colors,
    required this.onPlaceShape,
    required this.onPaint,
    this.blockedShapeIds = const <String>{},
    this.enabled = true,
  });

  final List<Shape> shapes;
  final List<QuadColor> colors;
  final TrayShapeTap onPlaceShape;
  final TrayColorTap onPaint;

  /// Blueprints that cannot currently be placed, shown dimmed.
  final Set<String> blockedShapeIds;

  /// When false (e.g. a flight is in progress), taps are ignored.
  final bool enabled;

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
              Overline(
                'tap to place',
                color: Palette.inkFaint.withValues(alpha: 0.8),
              ),
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
                      enabled: enabled,
                      onTap: (origin) => onPlaceShape(shape, origin),
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
                    enabled: enabled,
                    onTap: (origin) => onPaint(colors[index], origin),
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

Rect? _globalBoundsOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _ShapeChip extends StatelessWidget {
  const _ShapeChip({
    required this.shape,
    required this.blocked,
    required this.enabled,
    required this.onTap,
  });

  final Shape shape;
  final bool blocked;
  final bool enabled;
  final ValueChanged<Rect> onTap;

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
      enabled: enabled && !blocked,
      label: 'Blueprint ${shape.id}',
      child: SizedBox(
        width: 78,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: !enabled || blocked
                ? null
                : () {
                    final origin = _globalBoundsOf(context);
                    if (origin != null) onTap(origin);
                  },
            child: well,
          ),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final QuadColor color;
  final bool enabled;
  final ValueChanged<Rect> onTap;

  @override
  Widget build(BuildContext context) {
    final swatch = _Swatch(color: color, diameter: 48);
    return Semantics(
      button: true,
      enabled: enabled,
      label: '${Palette.label(color)} paint',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: !enabled
              ? null
              : () {
                  final origin = _globalBoundsOf(context);
                  if (origin != null) onTap(origin);
                },
          child: swatch,
        ),
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
        color: Palette.piece(color),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.45),
          width: 1.5,
        ),
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

/// Scale-in used when a blueprint appears (level load or a fresh cut).
class _ChipEntrance extends StatefulWidget {
  const _ChipEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<_ChipEntrance> createState() => _ChipEntranceState();
}

class _ChipEntranceState extends State<_ChipEntrance>
    with SingleTickerProviderStateMixin {
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
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    return ScaleTransition(
      scale: Tween(begin: 0.7, end: 1.0).animate(curve),
      child: FadeTransition(opacity: _controller, child: widget.child),
    );
  }
}

/// Flies [child] from [from] to [to] over the app overlay, then completes.
Future<void> flyToBoard({
  required BuildContext context,
  required Rect from,
  required Rect to,
  required Widget child,
  Duration duration = const Duration(milliseconds: 320),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return Future.value();

  final completer = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _FlightLayer(
      from: from,
      to: to,
      duration: duration,
      onDone: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
      child: child,
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _FlightLayer extends StatefulWidget {
  const _FlightLayer({
    required this.from,
    required this.to,
    required this.duration,
    required this.onDone,
    required this.child,
  });

  final Rect from;
  final Rect to;
  final Duration duration;
  final VoidCallback onDone;
  final Widget child;

  @override
  State<_FlightLayer> createState() => _FlightLayerState();
}

class _FlightLayerState extends State<_FlightLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: motion,
        builder: (context, child) {
          final t = motion.value;
          // Slight arc upward mid-flight.
          final lift = (1 - (2 * t - 1).abs()) * 36;
          final rect = Rect.lerp(widget.from, widget.to, t)!;
          final scale = lerpDouble(1.0, 1.15, (1 - (2 * t - 1).abs()))!;
          final opacity = t < 0.85 ? 1.0 : (1 - (t - 0.85) / 0.15);

          return Stack(
            children: [
              Positioned(
                left: rect.left,
                top: rect.top - lift,
                width: rect.width,
                height: rect.height,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Palette.brass.withValues(alpha: 0.22 * opacity),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}
