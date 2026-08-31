import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/shape/shape.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Tap callbacks include the chip's global bounds so the play screen can fly
/// a ghost from the tray to the plate.
typedef TrayShapeTap = void Function(Shape shape, Rect globalOrigin);
typedef TrayColorTap = void Function(QuadColor color, Rect globalOrigin);

/// Bottom tray: reusable blueprints and paints. Flush, full-bleed and one
/// shade darker than the board above it — a shelf built into the surface,
/// not a card floating on it. A row that overflows fades at the edge it
/// still has more to show, rather than spilling past a card or hard-clipping.
class TrayStrip extends ConsumerWidget {
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

  static const _hPad = 20.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return ColoredBox(
      color: Palette.panelSunken,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _hPad),
              child: Row(
                children: [
                  Overline(l10n.blueprints),
                  const Spacer(),
                  Overline(
                    l10n.tapToPlace,
                    color: Palette.inkFaint.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (shapes.isEmpty)
              const _EmptyTrayHint()
            else
              _EdgeFadeRow(
                height: 78,
                fadeColor: Palette.panelSunken,
                itemCount: shapes.length,
                separatorWidth: 10,
                padding: _hPad,
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
            if (colors.isNotEmpty) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _hPad),
                child: Overline(l10n.paint),
              ),
              const SizedBox(height: 10),
              _EdgeFadeRow(
                height: 52,
                fadeColor: Palette.panelSunken,
                itemCount: colors.length,
                separatorWidth: 14,
                padding: _hPad,
                itemBuilder: (context, index) => _ChipEntrance(
                  key: ValueKey('paint-${colors[index].name}'),
                  child: _ColorChip(
                    color: colors[index],
                    enabled: enabled,
                    onTap: (origin) => onPaint(colors[index], origin),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyTrayHint extends ConsumerWidget {
  const _EmptyTrayHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    height: 78,
    alignment: Alignment.center,
    child: Text(
      ref.watch(l10nProvider).emptyTray,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

/// A horizontally scrolling row whose edges fade out honestly: a side only
/// fades once there is something to scroll back to on it, and the fade
/// clears once you've reached that end — the flush answer to a row that
/// used to either spill past its card or cut its last chip off dead flat.
class _EdgeFadeRow extends StatefulWidget {
  const _EdgeFadeRow({
    required this.height,
    required this.itemCount,
    required this.separatorWidth,
    required this.padding,
    required this.fadeColor,
    required this.itemBuilder,
  });

  final double height;
  final int itemCount;
  final double separatorWidth;
  final double padding;
  final Color fadeColor;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_EdgeFadeRow> createState() => _EdgeFadeRowState();
}

class _EdgeFadeRowState extends State<_EdgeFadeRow> {
  static const _fadeWidth = 28.0;
  static const _fadeSpan = 24.0;

  final _controller = ScrollController();
  double _leftFade = 0;
  double _rightFade = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateFade);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFade());
  }

  @override
  void dispose() {
    _controller.removeListener(_updateFade);
    _controller.dispose();
    super.dispose();
  }

  void _updateFade() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final left = ((position.pixels - position.minScrollExtent) / _fadeSpan)
        .clamp(0.0, 1.0);
    final right = ((position.maxScrollExtent - position.pixels) / _fadeSpan)
        .clamp(0.0, 1.0);
    if (left == _leftFade && right == _rightFade) return;
    setState(() {
      _leftFade = left;
      _rightFade = right;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _updateFade());
          return false;
        },
        child: Stack(
          children: [
            ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: widget.padding),
              itemCount: widget.itemCount,
              separatorBuilder: (_, _) =>
                  SizedBox(width: widget.separatorWidth),
              itemBuilder: widget.itemBuilder,
            ),
            _edge(atLeft: true, opacity: _leftFade),
            _edge(atLeft: false, opacity: _rightFade),
          ],
        ),
      ),
    );
  }

  Widget _edge({required bool atLeft, required double opacity}) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Positioned(
      left: atLeft ? 0 : null,
      right: atLeft ? null : 0,
      top: 0,
      bottom: 0,
      width: _fadeWidth,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: atLeft ? Alignment.centerLeft : Alignment.centerRight,
                end: atLeft ? Alignment.centerRight : Alignment.centerLeft,
                colors: [
                  widget.fadeColor,
                  widget.fadeColor.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Rect? _globalBoundsOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _ShapeChip extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final well = Opacity(
      opacity: blocked ? 0.4 : 1,
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Palette.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.biggest.shortestSide;
                return ShapeView(shape: shape, size: side);
              },
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled && !blocked,
      label: ref.watch(l10nProvider).blueprintLabel(shape.id),
      child: SizedBox(
        width: 78,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
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

class _ColorChip extends ConsumerWidget {
  const _ColorChip({
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final QuadColor color;
  final bool enabled;
  final ValueChanged<Rect> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final swatch = _Swatch(color: color, diameter: 48);
    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.paintLabel(l10n.colorName(color)),
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
          color: Colors.black.withValues(alpha: 0.35),
          width: 2,
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
  bool fadeOut = true,
  double lift = 36,
  double midScale = 1.15,
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
      fadeOut: fadeOut,
      lift: lift,
      midScale: midScale,
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
    required this.fadeOut,
    required this.lift,
    required this.midScale,
    required this.onDone,
    required this.child,
  });

  final Rect from;
  final Rect to;
  final Duration duration;
  final bool fadeOut;
  final double lift;
  final double midScale;
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
          final lift = (1 - (2 * t - 1).abs()) * widget.lift;
          final rect = Rect.lerp(widget.from, widget.to, t)!;
          final scale = lerpDouble(
            1.0,
            widget.midScale,
            (1 - (2 * t - 1).abs()),
          )!;
          final opacity = widget.fadeOut && t > 0.85
              ? (1 - (t - 0.85) / 0.15)
              : 1.0;

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
                            color: Palette.brass.withValues(
                              alpha: 0.22 * opacity,
                            ),
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
