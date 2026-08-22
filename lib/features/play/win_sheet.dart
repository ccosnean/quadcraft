import 'package:flutter/material.dart';

import '../../core/level/level.dart';
import '../../data/progress_store.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

enum WinAction { replay, next, levels }

/// Level-clear summary. Shown as a non-dismissible sheet so the run always
/// ends with an explicit choice.
class WinSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final beatPar = result.moves <= level.parMoves;

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
                        Text('Solved', style: text.titleLarge),
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
                label: 'Moves',
                value: '${result.moves}',
                sub: 'best ${result.bestMoves}  ·  par ${level.parMoves}',
                badge: result.isNewBestMoves && !result.isFirstClear ? 'New best' : null,
                highlight: beatPar,
              ),
              const SizedBox(height: 12),
              Text(
                beatPar
                    ? 'Clean line. That matches the intended solution.'
                    : 'Solved in ${result.moves} moves. Par is ${level.parMoves}.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ActionButton(
                    label: 'Replay',
                    icon: Icons.refresh_rounded,
                    onPressed: () => Navigator.of(context).pop(WinAction.replay),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      label: hasNext ? 'Next level' : 'All levels',
                      icon: hasNext ? Icons.arrow_forward_rounded : Icons.grid_view_rounded,
                      primary: true,
                      expand: true,
                      onPressed: () => Navigator.of(context)
                          .pop(hasNext ? WinAction.next : WinAction.levels),
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
        border: Border.all(color: highlight ? Palette.brassDim : Palette.hairline),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
