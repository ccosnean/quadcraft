import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../audio/sfx.dart';
import '../../core/level/level.dart';
import '../../core/level/levels.dart';
import '../../core/shape/shape.dart';
import '../../core/shape/shape_ops.dart';
import '../../ui/grain_background.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'board_stage.dart';
import 'confetti.dart';
import 'play_controller.dart';
import 'tray_strip.dart';
import 'win_sheet.dart';

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key, required this.levelNumber});

  final int levelNumber;

  static Route<void> route(int levelNumber) =>
      MaterialPageRoute(builder: (_) => PlayScreen(levelNumber: levelNumber));

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  final GlobalKey _boardKey = GlobalKey();
  int _confetti = 0;
  bool _sheetOpen = false;
  bool _flying = false;
  Timer? _winTimer;

  PlayController get _controller =>
      ref.read(playControllerProvider(widget.levelNumber).notifier);

  @override
  void dispose() {
    _winTimer?.cancel();
    super.dispose();
  }

  Rect? get _boardRect {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _placeShape(Shape shape, Rect origin) async {
    if (_flying || _sheetOpen) return;
    final target = _boardRect;
    if (target == null) {
      _controller.drop(shape);
      return;
    }
    setState(() => _flying = true);
    ref.read(soundBankProvider).play(Sfx.pickup);
    // Fly a slightly larger ghost into the plate, then commit the place.
    final ghostSize = math.min(target.shortestSide * 0.72, 160.0);
    final dest = Rect.fromCenter(
      center: target.center,
      width: ghostSize,
      height: ghostSize,
    );
    await flyToBoard(
      context: context,
      from: origin,
      to: dest,
      child: ShapeView(shape: shape, size: ghostSize),
    );
    if (!mounted) return;
    _controller.drop(shape);
    setState(() => _flying = false);
  }

  Future<void> _paintColor(QuadColor color, Rect origin) async {
    if (_flying || _sheetOpen) return;
    final target = _boardRect;
    if (target == null) {
      _controller.paint(color);
      return;
    }
    setState(() => _flying = true);
    ref.read(soundBankProvider).play(Sfx.pickup);
    final ghostSize = 56.0;
    final dest = Rect.fromCenter(
      center: target.center,
      width: ghostSize,
      height: ghostSize,
    );
    await flyToBoard(
      context: context,
      from: origin,
      to: dest,
      child: Container(
        width: ghostSize,
        height: ghostSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Palette.piece(color),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Palette.piece(color).withValues(alpha: 0.4),
              blurRadius: 18,
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    _controller.paint(color);
    setState(() => _flying = false);
  }

  /// Lets the confetti and the plate glow land before the sheet covers them.
  void _celebrate(Level level) {
    if (_sheetOpen) return;
    _sheetOpen = true;
    setState(() => _confetti++);
    _winTimer?.cancel();
    _winTimer = Timer(
      const Duration(milliseconds: 750),
      () => _openWinSheet(level),
    );
  }

  Future<void> _openWinSheet(Level level) async {
    if (!mounted) return;

    final state = ref.read(playControllerProvider(widget.levelNumber));
    final result = state.clear;
    if (result == null) return;

    final hasNext = level.number < kLevels.length;
    final action = await showModalBottomSheet<WinAction>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => WinSheet(level: level, result: result, hasNext: hasNext),
    );
    if (!mounted) return;
    _sheetOpen = false;

    switch (action) {
      case WinAction.replay:
        _controller.reset();
      case WinAction.next:
        Navigator.of(
          context,
        ).pushReplacement(PlayScreen.route(level.number + 1));
      case WinAction.levels:
      case null:
        Navigator.of(context).pop();
    }
  }

  void _showHint(Level level) {
    final move = _controller.revealHint();
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: Palette.panelRaised,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Palette.brassDim),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.lightbulb_outline_rounded,
              color: Palette.brassBright,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: _hintBody(move)),
          ],
        ),
      ),
    );
  }

  Widget _hintBody(GameMove? move) {
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Palette.ink);
    switch (move) {
      case null:
        return Text(
          'Nothing left to suggest. The plate should match already.',
          style: style,
        );
      case RotateMove():
        return Text('Turn the plate a quarter clockwise.', style: style);
      case CutMove():
        return Text('Cut the plate and bank both halves.', style: style);
      case PaintMove(:final color):
        return Text(
          'Paint everything ${Palette.label(color).toLowerCase()}.',
          style: style,
        );
      case StackMove(:final shapeId):
        return Row(
          children: [
            Flexible(child: Text('Place this blueprint.', style: style)),
            const SizedBox(width: 10),
            ShapeView(shape: Shape.parse(shapeId), size: 30),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = playControllerProvider(widget.levelNumber);
    final state = ref.watch(provider);
    final level = state.level;

    ref.listen(provider.select((s) => s.clear), (previous, next) {
      if (next != null && previous == null) _celebrate(level);
    });

    final board = state.game.board;
    final blockedIds = {
      for (final shape in state.game.tray)
        if (!ShapeOps.canStack(board, shape)) shape.id,
    };

    return Scaffold(
      body: GrainBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _TopBar(level: level, onHint: () => _showHint(level)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _GoalHeader(level: level, state: state),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = math
                              .min(constraints.maxWidth, constraints.maxHeight)
                              .clamp(200.0, 380.0);
                          return Center(
                            child: BoardStage(
                              key: _boardKey,
                              shape: board,
                              size: size,
                              effect: state.effect,
                              effectId: state.effectId,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 260),
                    opacity: state.solved ? 0.35 : 1,
                    child: IgnorePointer(
                      ignoring: state.solved,
                      child: Column(
                        children: [
                          _ToolRow(
                            level: level,
                            state: state,
                            controller: _controller,
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: TrayStrip(
                              shapes: state.game.tray,
                              colors: level.colors,
                              blockedShapeIds: blockedIds,
                              enabled: !_flying,
                              onPlaceShape: _placeShape,
                              onPaint: _paintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(child: ConfettiBurst(trigger: _confetti)),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.level, required this.onHint});

  final Level level;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = ref.watch(mutedProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left_rounded, size: 30),
            color: Palette.inkMuted,
            tooltip: 'Back to levels',
          ),
          Expanded(
            child: Column(
              children: [
                Overline('level ${level.number.toString().padLeft(2, '0')}'),
                const SizedBox(height: 1),
                Text(
                  level.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onHint,
            icon: const Icon(Icons.lightbulb_outline_rounded),
            color: Palette.inkMuted,
            tooltip: 'Hint',
          ),
          IconButton(
            onPressed: () => ref.read(mutedProvider.notifier).toggle(),
            icon: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            ),
            color: Palette.inkMuted,
            tooltip: muted ? 'Unmute' : 'Mute',
          ),
        ],
      ),
    );
  }
}

class _GoalHeader extends StatelessWidget {
  const _GoalHeader({required this.level, required this.state});

  final Level level;
  final PlayState state;

  void _openPreview(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close target preview',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondary) {
        return SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: _TargetPreviewDialog(goal: level.goal, name: level.name),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 12, 22, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openPreview(context),
              borderRadius: BorderRadius.circular(18),
              child: Tooltip(
                message: 'Tap to enlarge',
                child: Plate(
                  radius: 18,
                  padding: const EdgeInsets.all(8),
                  child: SizedBox.square(
                    dimension: 72,
                    child: ShapeView(shape: level.goal, size: 72),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Overline('target'),
                const SizedBox(height: 6),
                Text(
                  level.brief,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Readout(label: 'moves', value: '${state.game.moves}'),
        ],
      ),
    );
  }
}

class _TargetPreviewDialog extends StatelessWidget {
  const _TargetPreviewDialog({required this.goal, required this.name});

  final Shape goal;
  final String name;

  @override
  Widget build(BuildContext context) {
    final side = (MediaQuery.sizeOf(context).shortestSide * 0.72).clamp(
      220.0,
      340.0,
    );
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Overline('target'),
            const SizedBox(height: 8),
            Text(name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Plate(
              radius: 28,
              padding: const EdgeInsets.all(18),
              child: SizedBox.square(
                dimension: side,
                child: ShapeView(shape: goal, size: side),
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.level,
    required this.state,
    required this.controller,
  });

  final Level level;
  final PlayState state;
  final PlayController controller;

  @override
  Widget build(BuildContext context) {
    final board = state.game.board;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ToolButton(
          icon: Icons.rotate_right_rounded,
          label: 'Turn',
          accent: level.canRotate,
          onPressed: board.isEmpty ? null : controller.rotate,
        ),
        const SizedBox(width: 10),
        ToolButton(
          icon: Icons.content_cut_rounded,
          label: 'Cut',
          accent: false,
          onPressed: board.isEmpty ? null : controller.cut,
        ),
        const SizedBox(width: 10),
        ToolButton(
          icon: Icons.undo_rounded,
          label: 'Undo',
          onPressed: state.canUndo ? controller.undo : null,
        ),
        const SizedBox(width: 10),
        ToolButton(
          icon: Icons.restart_alt_rounded,
          label: 'Reset',
          onPressed: state.game.moves == 0 ? null : controller.reset,
        ),
      ],
    );
  }
}
