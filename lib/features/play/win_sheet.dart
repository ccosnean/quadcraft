import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/level/level.dart';
import '../../data/progress_store.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

import 'share_card.dart';

enum WinAction { replay, next, levels }

/// Level-clear summary. Shown as a non-dismissible sheet so the run always
/// ends with an explicit choice.
class WinSheet extends ConsumerWidget {
  const WinSheet({
    super.key,
    required this.level,
    required this.result,
    required this.hasNext,
  });

  final Level level;
  final ClearResult result;
  final bool hasNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final l10n = ref.watch(l10nProvider);
    final newBest = result.isNewBestMoves || result.isFirstClear;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.panelRaised, Palette.backdropBottom],
        ),
        border: Border(top: BorderSide(color: Palette.brassDim, width: 1.4)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Plate(
                    radius: 20,
                    padding: const EdgeInsets.all(8),
                    glow: 0.6,
                    glowColor: Palette.brassBright,
                    child: ShapeView(shape: level.goal, size: 62),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.solved, style: text.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          '${level.number.toString().padLeft(2, '0')}  ${level.name}',
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _StatTile(
                label: l10n.moves,
                value: '${result.moves}',
                sub: result.isFirstClear
                    ? l10n.yourScoreToBeat
                    : l10n.personalBest(result.bestMoves),
                badge: result.isNewBestMoves && !result.isFirstClear
                    ? l10n.newBest
                    : null,
                highlight: newBest,
              ),
              const SizedBox(height: 12),
              Text(
                newBest
                    ? l10n.sharePromptNew(result.moves)
                    : l10n.sharePromptRepeat(result.moves, result.bestMoves),
                style: text.bodySmall,
              ),
              const SizedBox(height: 20),
              ActionButton(
                label: l10n.share,
                icon: Icons.ios_share_rounded,
                expand: true,
                onPressed: () => showShareScoreSheet(
                  context: context,
                  level: level,
                  moves: result.moves,
                  isNewBest: newBest,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      label: l10n.replay,
                      icon: Icons.refresh_rounded,
                      expand: true,
                      onPressed: () =>
                          Navigator.of(context).pop(WinAction.replay),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      label: hasNext ? l10n.nextLevel : l10n.allLevels,
                      icon: hasNext
                          ? Icons.arrow_forward_rounded
                          : Icons.grid_view_rounded,
                      primary: true,
                      expand: true,
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(hasNext ? WinAction.next : WinAction.levels),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    this.badge,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String sub;
  final String? badge;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Palette.panelSunken,
        border: Border.all(
          color: highlight ? Palette.brassDim : Palette.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Overline(label),
              if (badge != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Palette.brass.withValues(alpha: 0.18),
                    border: Border.all(color: Palette.brassDim),
                  ),
                  child: Text(
                    badge!.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Palette.brassBright,
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.monoDigits.copyWith(
              fontSize: 26,
              color: highlight ? Palette.brassBright : Palette.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(sub, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
