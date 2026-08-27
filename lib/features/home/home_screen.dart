import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../audio/sfx.dart';
import '../../core/level/levels.dart';
import '../../core/shape/shape.dart';
import '../../ui/grain_background.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../levels/level_select_screen.dart';
import '../play/play_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final muted = ref.watch(mutedProvider);
    final l10n = ref.watch(l10nProvider);
    final resume = progress.unlocked.clamp(1, kLevels.length);
    final started = progress.clearedCount > 0;

    return Scaffold(
      body: GrainBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        ref.read(soundBankProvider).play(Sfx.tap);
                        Navigator.of(context).push(SettingsScreen.route());
                      },
                      icon: const Icon(Icons.settings_rounded),
                      color: Palette.inkMuted,
                      tooltip: l10n.settings,
                    ),
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
                Text(
                  'QUADCRAFT',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                const _AttractShape(),
                const Spacer(flex: 2),
                ActionButton(
                  label: started ? l10n.continueLevel(resume) : l10n.start,
                  icon: Icons.play_arrow_rounded,
                  primary: true,
                  expand: true,
                  onPressed: () {
                    ref.read(soundBankProvider).play(Sfx.tap);
                    Navigator.of(context).push(PlayScreen.route(resume));
                  },
                ),
                const SizedBox(height: 12),
                ActionButton(
                  label: l10n.allLevels,
                  icon: Icons.grid_view_rounded,
                  expand: true,
                  onPressed: () {
                    ref.read(soundBankProvider).play(Sfx.tap);
                    Navigator.of(context).push(LevelSelectScreen.route());
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.solvedCount(progress.clearedCount, kLevels.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
              ],
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
  const _AttractShape();

  @override
  State<_AttractShape> createState() => _AttractShapeState();
}

class _AttractShapeState extends State<_AttractShape>
    with SingleTickerProviderStateMixin {
  static final _showcase = [
    Shape.parse('Po/Cm/Po/Cm'),
    Shape.parse('Lm+Cp/Lm+Cp/Lm+Cp/Lm+Cp'),
    Shape.parse('Tr+Cc/Ty+Cc/Tb+Cc/Tg+Cc'),
    Shape.parse('Pr+Cu/Lo/Tm/Wp'),
  ];

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
      if (_quarter % 4 == 0) _index = (_index + 1) % _showcase.length;
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Quarter turn over the first 60% of each cycle, then a beat of rest.
        final t = Curves.easeInOutCubic.transform(
          (_controller.value / 0.6).clamp(0.0, 1.0),
        );
        final angle = (math.pi / 2) * (_quarter + t);
        return Plate(
          radius: 32,
          padding: const EdgeInsets.all(14),
          glow: 0.25,
          child: Transform.rotate(
            angle: angle,
            child: ShapeView(
              shape: _showcase[_index],
              size: 176,
              showGuides: true,
            ),
          ),
        );
      },
    );
  }
}
