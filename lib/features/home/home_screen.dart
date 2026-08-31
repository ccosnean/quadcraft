import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../audio/sfx.dart';
import '../../core/level/level.dart';
import '../../core/level/levels.dart';
import '../../core/shape/shape.dart';
import '../../ui/grain_background.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../levels/level_select_screen.dart';
import '../play/play_screen.dart';
import '../play/shared_level_sheet.dart';
import '../settings/settings_screen.dart';
import 'seed_sheet.dart';
import 'showcase.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final muted = ref.watch(mutedProvider);
    final l10n = ref.watch(l10nProvider);
    final dive = ref.watch(diveProvider);
    // Resume picks up wherever the ladder left off: still in the tutorial, or
    // at the frontier depth once it is behind you.
    final resume = progress.diveOpen
        ? dive.frontier
        : LevelRef.campaign(progress.unlocked.clamp(1, kLevels.length));
    final started = progress.clearedCount > 0;

    return Scaffold(
      body: GrainBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            // Roomy screens space the menu out; short ones — a small phone, a
            // long translation, a large font — let it scroll rather than
            // clipping a button off the bottom.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                ref.read(soundBankProvider).play(Sfx.tap);
                                Navigator.of(
                                  context,
                                ).push(SettingsScreen.route());
                              },
                              icon: const Icon(Icons.settings_rounded),
                              color: Palette.inkMuted,
                              tooltip: l10n.settings,
                            ),
                            const Spacer(),
                            // The seed is the one thing on this screen that says which
                            // game you are playing, so it sits with the chrome rather
                            // than buried in settings.
                            const SeedCard(),
                            const Spacer(),
                            IconButton(
                              onPressed: () =>
                                  ref.read(mutedProvider.notifier).toggle(),
                              icon: Icon(
                                muted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                              ),
                              color: Palette.inkMuted,
                              tooltip: muted ? l10n.unmute : l10n.mute,
                            ),
                          ],
                        ),
                        const Spacer(flex: 2),
                        // The wordmark is tracked wide enough to wrap on a
                        // narrow phone, which reads as a bug. It comes down
                        // in size instead.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'QUADCRAFT',
                            maxLines: 1,
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.tagline,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        // The showcase is the one thing here that can afford to give
                        // ground: on a short screen it comes down in size rather than
                        // pushing the buttons off the bottom.
                        _AttractShape(
                          showcase: ref.watch(showcaseProvider(dive.seed)),
                          size: (constraints.maxHeight * 0.26).clamp(
                            96.0,
                            176.0,
                          ),
                        ),
                        const Spacer(flex: 2),
                        ActionButton(
                          // Once the ladder is open it is the game, and the button
                          // says which rung — however the tutorial was got past.
                          label: progress.diveOpen
                              ? l10n.depthLabel(resume.number)
                              : (started
                                    ? l10n.continueTutorial(resume.number)
                                    : l10n.start),
                          icon: Icons.play_arrow_rounded,
                          primary: true,
                          expand: true,
                          onPressed: () {
                            ref.read(soundBankProvider).play(Sfx.tap);
                            Navigator.of(
                              context,
                            ).push(PlayScreen.route(resume));
                          },
                        ),
                        const SizedBox(height: 12),
                        ActionButton(
                          label: l10n.allLevels,
                          icon: Icons.grid_view_rounded,
                          expand: true,
                          onPressed: () {
                            ref.read(soundBankProvider).play(Sfx.tap);
                            Navigator.of(
                              context,
                            ).push(LevelSelectScreen.route());
                          },
                        ),
                        const SizedBox(height: 12),
                        ActionButton(
                          key: const Key('home-shared-level'),
                          label: l10n.playShared,
                          icon: Icons.qr_code_rounded,
                          expand: true,
                          onPressed: () {
                            ref.read(soundBankProvider).play(Sfx.tap);
                            showSharedLevelSheet(context);
                          },
                        ),
                        // The lessons are worth playing, but they are not a toll.
                        // Skipping is one tap and settings can walk back in.
                        if (progress.canSkipTutorial) ...[
                          const SizedBox(height: 6),
                          TextButton(
                            key: const Key('home-skip-tutorial'),
                            onPressed: () {
                              ref.read(soundBankProvider).play(Sfx.tap);
                              ref
                                  .read(progressProvider.notifier)
                                  .skipTutorial();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Palette.inkFaint,
                              textStyle: Theme.of(context).textTheme.bodySmall,
                            ),
                            child: Text(l10n.skipTutorial),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          progress.diveOpen
                              ? l10n.clearedThisRun(dive.clears)
                              : l10n.solvedCount(
                                  progress.clearedCount,
                                  kLevels.length,
                                ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Idle showcase: a shape that keeps turning a quarter at a time, using the
/// same easing as the board so the menu previews the game's feel.
class _AttractShape extends StatefulWidget {
  const _AttractShape({required this.showcase, required this.size});

  /// The run's own best-looking targets, filled in as the scan finds them.
  final ShowcaseShapes showcase;

  final double size;

  @override
  State<_AttractShape> createState() => _AttractShapeState();
}

class _AttractShapeState extends State<_AttractShape>
    with SingleTickerProviderStateMixin {
  /// What turns while the run's own shapes are still being found, and the one
  /// thing here that is not seeded: the very first frame has nothing yet.
  static final _opening = Shape.parse('Lm+Cp/Lm+Cp/Lm+Cp/Lm+Cp');

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  int _quarter = 0;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _quarter++;
      // Swap the showcase piece after every full revolution.
      if (_quarter % 4 == 0) _index++;
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.showcase,
      builder: (context, _) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Quarter turn over the first 60% of each cycle, then a beat of rest.
          final t = Curves.easeInOutCubic.transform(
            (_controller.value / 0.6).clamp(0.0, 1.0),
          );
          final angle = (math.pi / 2) * (_quarter + t);
          final found = widget.showcase.shapes;
          return Plate(
            radius: 32,
            padding: const EdgeInsets.all(14),
            glow: 0.25,
            child: Transform.rotate(
              angle: angle,
              child: ShapeView(
                shape: found.isEmpty
                    ? _opening
                    : found[_index % found.length],
                size: widget.size,
                showGuides: true,
              ),
            ),
          );
        },
      ),
    );
  }
}
