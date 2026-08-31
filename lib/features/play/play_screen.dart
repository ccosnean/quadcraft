import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../audio/sfx.dart';
import '../../core/level/level.dart';
import '../../core/level/level_catalog.dart';
import '../../core/shape/shape.dart';
import '../../core/shape/shape_ops.dart';
import '../../data/progress_store.dart';
import '../../l10n/l10n.dart';
import '../../ui/grain_background.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'board_stage.dart';
import 'confetti.dart';
import 'play_controller.dart';
import 'shared_level_sheet.dart';
import 'tray_strip.dart';
import 'win_sheet.dart';

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key, required this.level, this.movesToBeat});

  final LevelRef level;

  /// Score to beat, when the level was opened from somebody's share code.
  /// Presentation only — it never reaches the engine or the record.
  final int? movesToBeat;

  static Route<void> route(LevelRef level, {int? movesToBeat}) =>
      MaterialPageRoute(
        builder: (_) => PlayScreen(level: level, movesToBeat: movesToBeat),
      );

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

/// Hairline seam between the screen's flush zones — a header, a target
/// strip, the board, the tools and the tray all sit on one surface rather
/// than as separate floating cards, and this is the only thing marking
/// where one zone ends and the next begins.
const _seam = Divider(height: 1, thickness: 1, color: Palette.hairline);

class _PlayScreenState extends ConsumerState<PlayScreen> {
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _goalSlotKey = GlobalKey();
  final GlobalKey _introPlateKey = GlobalKey();
  int _confetti = 0;
  bool _sheetOpen = false;
  bool _flying = false;
  bool _targetIntro = true;
  bool _targetFlying = false;
  bool _autoOpened = false;
  Timer? _winTimer;
  Timer? _autoCloseTimer;

  PlayController get _controller =>
      ref.read(playControllerProvider(widget.level).notifier);

  @override
  void initState() {
    super.initState();
    final mode = ref.read(targetPreviewProvider);
    _targetIntro = mode != TargetPreviewMode.off;
    _autoOpened = mode == TargetPreviewMode.auto;
    if (_autoOpened) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _armAutoClose());
    }
  }

  @override
  void dispose() {
    _winTimer?.cancel();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _armAutoClose() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || !_targetIntro || _targetFlying) return;
      final level = ref.read(playControllerProvider(widget.level)).level;
      _dismissTargetIntro(level);
    });
  }

  Rect? get _boardRect {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _dismissTargetIntro(Level level) async {
    if (!_targetIntro || _targetFlying) return;
    _autoCloseTimer?.cancel();

    final fromBox =
        _introPlateKey.currentContext?.findRenderObject() as RenderBox?;
    final toBox = _goalSlotKey.currentContext?.findRenderObject() as RenderBox?;
    final from = (fromBox != null && fromBox.hasSize)
        ? fromBox.localToGlobal(Offset.zero) & fromBox.size
        : null;
    final to = (toBox != null && toBox.hasSize)
        ? toBox.localToGlobal(Offset.zero) & toBox.size
        : null;

    setState(() => _targetFlying = true);

    if (from != null && to != null && mounted) {
      await flyToBoard(
        context: context,
        from: from,
        to: to,
        duration: const Duration(milliseconds: 420),
        fadeOut: false,
        lift: 28,
        midScale: 1.06,
        child: FittedBox(
          child: _GoalPlate(
            goal: level.goal,
            side: _previewSide(context),
            glow: 18,
          ),
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _targetIntro = false;
      _targetFlying = false;
    });
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

    final state = ref.read(playControllerProvider(widget.level));
    final result = state.clear;
    if (result == null) return;

    // A challenge has no "next": the depth after it belongs to a run this
    // player is not on, so the sheet offers the seed instead of the ladder.
    final isChallenge = widget.level.isChallenge;
    final hasNext = !isChallenge && hasLevelAfter(level.ref);
    final action = await showModalBottomSheet<WinAction>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => WinSheet(
        level: level,
        result: result,
        hasNext: hasNext,
        isChallenge: isChallenge,
        movesToBeat: widget.movesToBeat,
      ),
    );
    if (!mounted) return;
    _sheetOpen = false;

    switch (action) {
      case WinAction.replay:
        _controller.reset();
      case WinAction.next:
        Navigator.of(context).pushReplacement(
          PlayScreen.route(
            nextAfter(level.ref, seed: ref.read(diveProvider).seed),
          ),
        );
      case WinAction.diveSeed:
        await _adoptSeed(level);
      case WinAction.levels:
      case null:
        Navigator.of(context).pop();
    }
  }

  /// Takes the seed of the level just played as this player's own run, and
  /// leaves them at the top of it.
  Future<void> _adoptSeed(Level level) async {
    if (!await confirmDiveThisSeed(context, ref)) {
      // Backing out of the warning should leave the clear sheet where it was,
      // not drop the player onto a solved board with nothing to press.
      if (mounted) {
        _sheetOpen = true;
        await _openWinSheet(level);
      }
      return;
    }
    if (!mounted) return;
    ref.read(diveProvider.notifier).useSeed(level.seed);
    ref.read(soundBankProvider).play(Sfx.tap);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showHint(Level level) {
    if (!_controller.state.canHint) return;
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
    final l10n = ref.read(l10nProvider);
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Palette.ink);
    switch (move) {
      case null:
        return Text(l10n.hintNone, style: style);
      case RotateMove():
        return Text(l10n.hintTurn, style: style);
      case CutMove():
        return Text(l10n.hintCut, style: style);
      case PaintMove(:final color):
        return Text(l10n.hintPaint(l10n.colorName(color)), style: style);
      case StackMove(:final shapeId):
        return Row(
          children: [
            Flexible(child: Text(l10n.hintPlace, style: style)),
            const SizedBox(width: 10),
            ShapeView(shape: Shape.parse(shapeId), size: 30),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = playControllerProvider(widget.level);
    final state = ref.watch(provider);
    final level = state.level;
    final l10n = ref.watch(l10nProvider);

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
                  _PlayHeader(
                    level: level,
                    isChallenge: widget.level.isChallenge,
                    movesToBeat: widget.movesToBeat,
                    state: state,
                    canHint: state.canHint,
                    hintsRemaining: state.hintsRemaining,
                    onHint: () => _showHint(level),
                    slotKey: _goalSlotKey,
                    hideSlot: _targetIntro || _targetFlying,
                  ),
                  _seam,
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
                          _seam,
                          _ToolRow(
                            level: level,
                            state: state,
                            controller: _controller,
                          ),
                          _seam,
                          TrayStrip(
                            shapes: state.game.tray,
                            colors: level.colors,
                            blockedShapeIds: blockedIds,
                            enabled: !_flying,
                            onPlaceShape: _placeShape,
                            onPaint: _paintColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: ConfettiBurst(
                trigger: _confetti,
                particles: ref.watch(confettiProvider).particles,
              ),
            ),
            if (_targetIntro)
              Positioned.fill(
                child: _TargetIntroOverlay(
                  goal: level.goal,
                  name: l10n.levelTitle(level),
                  plateKey: _introPlateKey,
                  dismissing: _targetFlying,
                  showDontAutoOpen: _autoOpened,
                  onDismiss: () => _dismissTargetIntro(level),
                  onDontAutoOpen: () {
                    ref
                        .read(targetPreviewProvider.notifier)
                        .set(TargetPreviewMode.off);
                    _dismissTargetIntro(level);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _goalHeroTag(LevelRef ref) => 'play-goal-$ref';

/// Above the title: which level of the campaign, or which band of the dive.
String _overline(L10n l10n, Level level) => switch (level.kind) {
  LevelKind.campaign => l10n.tutorialNumber(level.number),
  LevelKind.endless => l10n.stratumName(level.stratum),
};

double _previewSide(BuildContext context) =>
    (MediaQuery.sizeOf(context).shortestSide * 0.72).clamp(220.0, 340.0);

Tween<Rect?> _goalRectTween(Rect? begin, Rect? end) {
  if (begin == null || end == null) return RectTween(begin: begin, end: end);
  return MaterialRectArcTween(begin: begin, end: end);
}

/// The target shape shown bare — a soft brass halo standing in for the
/// boxed plate that used to frame it. Every place "the target" appears on
/// this screen (the header chip, the entry reveal, the enlarge dialog, and
/// the flight between them) goes through here, so they all read as one
/// identity.
class _GoalPlate extends StatelessWidget {
  const _GoalPlate({required this.goal, required this.side, this.glow = 14});

  final Shape goal;
  final double side;

  /// Radius of the halo beyond [side], in each direction.
  final double glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: side + glow * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: side + glow,
            height: side + glow,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Palette.brass.withValues(alpha: 0.2),
                  Palette.brass.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          ShapeView(shape: goal, size: side),
        ],
      ),
    );
  }
}

/// Top-of-screen chrome and the target strip, merged into one flush block:
/// back / title / hint, then the goal glyph, brief and move count. No card —
/// the seam below is what used to be a panel border.
class _PlayHeader extends ConsumerWidget {
  const _PlayHeader({
    required this.level,
    required this.isChallenge,
    required this.movesToBeat,
    required this.state,
    required this.canHint,
    required this.hintsRemaining,
    required this.onHint,
    required this.slotKey,
    required this.hideSlot,
  });

  final Level level;
  final bool isChallenge;

  /// The sharer's score, on a level opened from their code.
  final int? movesToBeat;

  /// What this player already did here, if they have cleared it before.
  ///
  /// A challenge has none: the puzzle is on somebody else's ladder, so there
  /// is no record of yours to beat — theirs is the only number that means
  /// anything, and it arrives as [movesToBeat].
  int? _personalBest(WidgetRef ref) {
    if (isChallenge) return null;
    return switch (level.kind) {
      LevelKind.campaign => ref.watch(progressProvider)[level.number]?.bestMoves,
      LevelKind.endless => ref.watch(diveProvider)[level.number]?.bestMoves,
    };
  }

  final PlayState state;
  final bool canHint;
  final int hintsRemaining;
  final VoidCallback onHint;
  final Key slotKey;
  final bool hideSlot;

  void _openPreview(BuildContext context, L10n l10n) {
    final tag = _goalHeroTag(level.ref);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n.closeTargetPreview,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (context, animation, secondary, child) => child,
      pageBuilder: (context, animation, secondary) {
        return SafeArea(
          child: Center(
            child: _TargetPreviewDialog(
              animation: animation,
              goal: level.goal,
              name: l10n.levelTitle(level),
              heroTag: tag,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.chevron_left_rounded, size: 30),
                color: Palette.inkMuted,
                tooltip: l10n.backToLevels,
              ),
              Expanded(
                child: Column(
                  children: [
                    Overline(
                      isChallenge ? l10n.sharedLevel : _overline(l10n, level),
                      color: isChallenge ? Palette.brass : null,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      l10n.levelTitle(level),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('hint'),
                onPressed: canHint ? onHint : null,
                icon: Badge(
                  isLabelVisible: true,
                  backgroundColor: canHint ? Palette.brass : Palette.hairline,
                  textColor: canHint
                      ? const Color(0xFF201704)
                      : Palette.inkFaint,
                  label: Text('$hintsRemaining'),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    color: canHint ? Palette.inkMuted : Palette.inkFaint,
                  ),
                ),
                tooltip: canHint ? l10n.hint : l10n.hintGone,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: hideSlot ? null : () => _openPreview(context, l10n),
                  customBorder: const CircleBorder(),
                  child: Tooltip(
                    message: l10n.tapToEnlarge,
                    child: Opacity(
                      opacity: hideSlot ? 0 : 1,
                      child: KeyedSubtree(
                        key: slotKey,
                        child: Hero(
                          tag: _goalHeroTag(level.ref),
                          createRectTween: _goalRectTween,
                          child: FittedBox(
                            child: _GoalPlate(goal: level.goal, side: 60),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Overline(l10n.target),
                    const SizedBox(height: 6),
                    Text(
                      l10n.levelLine(level),
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // The move counter is only meaningful against a number it has
              // to come in under, so where there is one it rides along and the
              // readout cools off the moment it is passed. On a challenge that
              // is the sharer's score; on anything already cleared it is the
              // player's own, which is the same question asked of yourself.
              Builder(
                builder: (context) {
                  final best = movesToBeat ?? _personalBest(ref);
                  return Readout(
                    label: l10n.moves,
                    value: '${state.scoredMoves}',
                    hint: best == null
                        ? null
                        : movesToBeat != null
                        ? l10n.movesToBeat(best)
                        : l10n.yourBest(best),
                    highlight: best != null && state.scoredMoves < best,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TargetPreviewDialog extends ConsumerWidget {
  const _TargetPreviewDialog({
    required this.animation,
    required this.goal,
    required this.name,
    required this.heroTag,
  });

  final Animation<double> animation;
  final Shape goal;
  final String name;
  final String heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final side = _previewSide(context);
    final chrome = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: chrome,
              child: Column(
                children: [
                  Overline(l10n.target),
                  const SizedBox(height: 8),
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Hero(
              tag: heroTag,
              createRectTween: _goalRectTween,
              child: FittedBox(
                child: _GoalPlate(goal: goal, side: side, glow: 18),
              ),
            ),
            const SizedBox(height: 18),
            FadeTransition(
              opacity: chrome,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetIntroOverlay extends ConsumerWidget {
  const _TargetIntroOverlay({
    required this.goal,
    required this.name,
    required this.plateKey,
    required this.dismissing,
    required this.showDontAutoOpen,
    required this.onDismiss,
    required this.onDontAutoOpen,
  });

  final Shape goal;
  final String name;
  final Key plateKey;
  final bool dismissing;
  final bool showDontAutoOpen;
  final VoidCallback onDismiss;
  final VoidCallback onDontAutoOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final side = _previewSide(context);
    return GestureDetector(
      key: const Key('target-intro'),
      behavior: HitTestBehavior.opaque,
      onTap: dismissing ? null : onDismiss,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        opacity: dismissing ? 0 : 1,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.72),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Overline(l10n.target),
                    const SizedBox(height: 8),
                    Text(name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 20),
                    Opacity(
                      opacity: dismissing ? 0 : 1,
                      child: KeyedSubtree(
                        key: plateKey,
                        child: _GoalPlate(goal: goal, side: side, glow: 18),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.tapAnywhere,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Palette.inkMuted),
                    ),
                    if (showDontAutoOpen) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('target-intro-dont-auto'),
                        onPressed: dismissing ? null : onDontAutoOpen,
                        child: Text(
                          l10n.dontAutoOpen,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: Palette.inkFaint),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Turn / cut / undo / reset, flush in one row. Neighbours are seamed by a
/// hairline rather than each sitting in its own bordered chip; a small dot
/// marks a tool this level has taught, replacing the old accent border.
class _ToolRow extends ConsumerWidget {
  const _ToolRow({
    required this.level,
    required this.state,
    required this.controller,
  });

  final Level level;
  final PlayState state;
  final PlayController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final board = state.game.board;
    final tools = [
      (
        icon: Icons.rotate_right_rounded,
        label: l10n.turn,
        accent: level.canRotate,
        onPressed: board.isEmpty ? null : controller.rotate,
      ),
      (
        icon: Icons.content_cut_rounded,
        label: l10n.cut,
        accent: level.canCut,
        onPressed: board.isEmpty ? null : controller.cut,
      ),
      (
        icon: Icons.undo_rounded,
        label: l10n.undo,
        accent: false,
        onPressed: state.canUndo ? controller.undo : null,
      ),
      (
        icon: Icons.restart_alt_rounded,
        label: l10n.reset,
        accent: false,
        onPressed: state.game.moves == 0 ? null : controller.reset,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < tools.length; i++) ...[
          if (i > 0)
            const SizedBox(
              height: 44,
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: Palette.hairline,
              ),
            ),
          Expanded(
            child: ToolButton(
              icon: tools[i].icon,
              label: tools[i].label,
              accent: tools[i].accent,
              onPressed: tools[i].onPressed,
            ),
          ),
        ],
      ],
    );
  }
}
