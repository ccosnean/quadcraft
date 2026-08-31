import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/level/level.dart';
import '../../data/progress_store.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

import 'share_card.dart';

enum WinAction { replay, next, levels, diveSeed }

/// Level-clear summary. Shown as a non-dismissible sheet so the run always
/// ends with an explicit choice.
class WinSheet extends ConsumerWidget {
  const WinSheet({
    super.key,
    required this.level,
    required this.result,
    required this.hasNext,
    this.isChallenge = false,
    this.movesToBeat,
  });

  final Level level;
  final ClearResult result;
  final bool hasNext;

  /// Somebody else's level. Nothing was recorded, so the sheet reports the
  /// attempt against their score instead of against a personal best.
  final bool isChallenge;

  /// What they took, when the code they sent carried it.
  final int? movesToBeat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final l10n = ref.watch(l10nProvider);
    final target = movesToBeat;
    final beatThem = isChallenge && target != null && result.moves < target;
    final newBest = isChallenge
        ? beatThem
        : (result.isNewBestMoves || result.isFirstClear);
    // The dive has two things worth calling out that the campaign does not:
    // going deeper than ever, and turning up a target nobody has built.
    final badges = <({String label, IconData? icon})>[
      if (isChallenge) (label: l10n.sharedLevel, icon: null),
      if (result.isNewDepth) (label: l10n.deepestYet, icon: null),
      if (result.isNewDiscovery) (label: l10n.newFind, icon: null),
      // A key is the one badge that hands over something spendable, so it
      // wears the same icon as the counter it just added to.
      if (result.earnedKey)
        (label: l10n.keyWon, icon: Icons.vpn_key_rounded),
      // Once per install, and worth more than any of the others.
      if (result.becameFreeExplorer)
        (label: l10n.freeExplorer, icon: Icons.explore_rounded),
    ];

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
                        Text(switch (level.kind) {
                          LevelKind.campaign =>
                            '${level.number.toString().padLeft(2, '0')}  '
                                '${level.name}',
                          LevelKind.endless =>
                            '${l10n.depthLabel(level.number)}  ·  '
                                '${l10n.stratumName(level.stratum)}',
                        }, style: text.bodyMedium),
                        if (badges.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final badge in badges)
                                _Badge(label: badge.label, icon: badge.icon),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _StatTile(
                label: l10n.moves,
                value: '${result.moves}',
                sub: switch ((isChallenge, target)) {
                  (true, final int n) => l10n.movesToBeat(n),
                  (true, _) => l10n.sharedNotCounted,
                  _ when result.isFirstClear => l10n.yourScoreToBeat,
                  _ => l10n.personalBest(result.bestMoves),
                },
                badge: switch ((isChallenge, beatThem)) {
                  (true, true) => l10n.beatenIt,
                  (true, false) => null,
                  _ =>
                    result.isNewBestMoves && !result.isFirstClear
                        ? l10n.newBest
                        : null,
                },
                highlight: newBest,
              ),
              const SizedBox(height: 12),
              Text(
                // A challenge already said in the tile that it counts for
                // nothing; what is worth saying here is that the level can
                // travel on, which is what the share button under this does.
                isChallenge
                    ? l10n.thinkYouCanBeat(result.moves)
                    : newBest
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
              // Adopting the seed is the only way a shared level leads
              // anywhere: the run it came from is not yours to walk, so the
              // offer is to start your own on the same ground.
              if (isChallenge && level.kind == LevelKind.endless) ...[
                const SizedBox(height: 12),
                ActionButton(
                  key: const Key('win-dive-seed'),
                  label: l10n.diveThisSeed,
                  icon: Icons.south_rounded,
                  expand: true,
                  onPressed: () =>
                      Navigator.of(context).pop(WinAction.diveSeed),
                ),
              ],
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
                      label: hasNext
                          ? (level.kind == LevelKind.endless
                                ? l10n.nextDepth
                                : l10n.nextLevel)
                          : l10n.allLevels,
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

/// Small brass pill for a one-off achievement on the clear sheet.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.icon});

  final String label;

  /// Shown before the label, for the badges that hand something over rather
  /// than just noting what happened.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Palette.brass.withValues(alpha: 0.18),
        border: Border.all(color: Palette.brassDim),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: Palette.brassBright),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Palette.brassBright,
              fontSize: 9,
            ),
          ),
        ],
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
