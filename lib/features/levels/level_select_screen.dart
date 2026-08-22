import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../audio/sfx.dart';
import '../../core/level/level.dart';
import '../../core/level/levels.dart';
import '../../data/progress_store.dart';
import '../../ui/grain_background.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../play/play_screen.dart';

class LevelSelectScreen extends ConsumerWidget {
  const LevelSelectScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const LevelSelectScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    return Scaffold(
      body: GrainBackground(
        bloom: 0.6,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.chevron_left_rounded, size: 30),
                      color: Palette.inkMuted,
                    ),
                    Expanded(
                      child: Text('Levels', style: Theme.of(context).textTheme.titleLarge),
                    ),
                    Text(
                      '${progress.clearedCount} / ${kLevels.length}',
                      style: AppTheme.monoDigits.copyWith(
                        fontSize: 16,
                        color: Palette.brassBright,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: kLevels.length,
                  itemBuilder: (context, index) {
                    final level = kLevels[index];
                    return _LevelCard(
                      level: level,
                      record: progress[level.number],
                      locked: !progress.isUnlocked(level.number),
                      onTap: () {
                        ref.read(soundBankProvider).play(Sfx.tap);
                        Navigator.of(context).push(PlayScreen.route(level.number));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.record,
    required this.locked,
    required this.onTap,
  });

  final Level level;
  final LevelRecord? record;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final best = record;
    final cleared = best != null;
    final text = Theme.of(context).textTheme;

    return Opacity(
      opacity: locked ? 0.4 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Palette.panelRaised, Palette.panel],
              ),
              border: Border.all(color: cleared ? Palette.brassDim : Palette.hairline),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      level.number.toString().padLeft(2, '0'),
                      style: AppTheme.monoDigits.copyWith(
                        fontSize: 13,
                        color: cleared ? Palette.brassBright : Palette.inkFaint,
                      ),
                    ),
                    const Spacer(),
                    if (locked)
                      const Icon(Icons.lock_rounded, size: 13, color: Palette.inkFaint)
                    else if (cleared)
                      const Icon(Icons.check_rounded, size: 14, color: Palette.brassBright),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: locked
                      ? const Center(
                          child: Icon(Icons.help_outline_rounded,
                              size: 26, color: Palette.inkFaint),
                        )
                      : ShapeView(shape: level.goal),
                ),
                const SizedBox(height: 6),
                Text(
                  locked ? 'Locked' : level.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: cleared ? Palette.inkMuted : Palette.inkFaint,
                  ),
                ),
                if (best != null)
                  Text(
                    '${best.bestMoves} moves',
                    style: text.bodySmall?.copyWith(fontSize: 10),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
