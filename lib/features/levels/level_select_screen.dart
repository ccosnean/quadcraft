import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../audio/sfx.dart';
import '../../core/level/endless/endless_tuning.dart';
import '../../core/level/level.dart';
import '../../core/level/level_catalog.dart';
import '../../core/level/levels.dart';
import '../../core/shape/shape.dart';
import '../../l10n/l10n.dart';
import '../../ui/grain_background.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../play/play_screen.dart';
import 'level_feed.dart';

/// The ladder in one list, and the list does not end.
///
/// Depths are drawn in named bands and built lazily as they scroll into view,
/// so there is no batch to finish and no button to press — the ladder simply
/// keeps going. Targets past the frontier are shown rather than hidden: you
/// can see what is coming, you just cannot open it yet.
///
/// The tutorial is not part of it. It is a fixed set of lessons that sits
/// outside every seed, so once it is behind you this screen is purely the
/// ladder your seed grew — and the tutorial is somewhere you go back to on
/// purpose, from settings, rather than something you scroll past forever.
class LevelSelectScreen extends ConsumerWidget {
  const LevelSelectScreen({super.key, this.tutorialOnly = false});

  /// Shows the lessons instead of the ladder. How settings reopens them.
  final bool tutorialOnly;

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const LevelSelectScreen());

  static Route<void> tutorial() => MaterialPageRoute(
    builder: (_) => const LevelSelectScreen(tutorialOnly: true),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final dive = ref.watch(diveProvider);
    final l10n = ref.watch(l10nProvider);

    // Before the lessons are done there is no ladder to show, so the list is
    // the lessons; afterwards it is the ladder, and the lessons only come back
    // when they are asked for by name.
    final showTutorial = tutorialOnly || !progress.diveOpen;
    final feed = ref.watch(levelFeedProvider(dive.seed));

    void open(LevelRef target) {
      ref.read(soundBankProvider).play(Sfx.tap);
      Navigator.of(context).push(PlayScreen.route(target));
    }

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
                      child: Text(
                        showTutorial ? l10n.tutorial : l10n.levels,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    // Keys are only meaningful where there are locks, so
                    // they show on the ladder and not over the lessons, and
                    // stop showing once the whole dive is open anyway.
                    if (!showTutorial && !dive.freeExplorer) ...[
                      Icon(
                        Icons.vpn_key_rounded,
                        size: 15,
                        color: dive.keysToday > 0
                            ? Palette.brassBright
                            : Palette.inkFaint,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${dive.keysToday}',
                        style: AppTheme.monoDigits.copyWith(
                          fontSize: 15,
                          color: dive.keysToday > 0
                              ? Palette.brassBright
                              : Palette.inkFaint,
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Text(
                      showTutorial
                          ? '${progress.clearedCount} / ${kLevels.length}'
                          : l10n.depthLabel(dive.deepest),
                      style: AppTheme.monoDigits.copyWith(
                        fontSize: 16,
                        color: Palette.brassBright,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    if (showTutorial)
                      for (final entry in kLevelSections) ...[
                        _Heading(entry.key),
                        _CardGrid(
                          count: entry.value.length,
                          builder: (index) {
                            final level = entry.value[index];
                            final record = progress[level.number];
                            final locked = !progress.isUnlocked(level.number);
                            return _LevelCard(
                              badge: level.number.toString().padLeft(2, '0'),
                              // The lessons still withhold what they have not
                              // taught yet; only the dive shows its future.
                              caption: locked ? l10n.locked : level.name,
                              goal: locked ? null : level.goal,
                              bestMoves: record?.bestMoves,
                              locked: locked,
                              movesLabel: l10n.bestMoves,
                              onTap: locked
                                  ? null
                                  : () => open(LevelRef.campaign(level.number)),
                            );
                          },
                        ),
                      ],
                    // Earned once, so it says so rather than the ladder just
                    // quietly stopping to have locks in it.
                    if (!showTutorial && dive.freeExplorer)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.explore_rounded,
                                  size: 18,
                                  color: Palette.brassBright,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.freeExplorer,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: Palette.brassBright,
                                          ),
                                    ),
                                    Text(
                                      l10n.freeExplorerNote,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Palette.inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!showTutorial)
                      SliverList(
                        // No childCount: the ladder is endless, so the list is
                        // too, and the viewport only ever builds what it can
                        // see. Each child is a whole named band, which is what
                        // lets headings sit between grids without the count
                        // having to be known up front.
                        delegate: SliverChildBuilderDelegate((context, band) {
                          if (band >= kMaxRevealedDepths ~/ kStratumSpan) {
                            return null;
                          }
                          return _DiveBand(
                            band: band,
                            feed: feed,
                            dive: dive,
                            l10n: l10n,
                            devUnlockAll: progress.devUnlockAll,
                            onOpen: open,
                            onRefused: (depth) =>
                                _refuse(context, ref, l10n, depth, open),
                          );
                        }),
                      ),
                    // Only while the lessons are the reason there is no
                    // ladder — not when they were opened on purpose.
                    if (!progress.diveOpen && !tutorialOnly)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Text(
                            l10n.diveLocked,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Palette.inkFaint),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What tapping a depth you have not reached does. The card is not inert —
/// showing the target and then ignoring the tap would read as a broken button
/// — so it says why, and offers the way past it if there is one.
void _refuse(
  BuildContext context,
  WidgetRef ref,
  L10n l10n,
  int depth,
  void Function(LevelRef) onOpen,
) {
  ref.read(soundBankProvider).play(Sfx.blocked);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final dive = ref.read(diveProvider);
  final spendable = dive.keysToday > 0;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(spendable ? l10n.goDeeperHint : l10n.outOfKeys),
        duration: const Duration(seconds: 4),
        action: spendable
            ? SnackBarAction(
                label: l10n.useKey,
                onPressed: () {
                  if (!ref.read(diveProvider.notifier).unlockWithKey(depth)) {
                    return;
                  }
                  ref.read(soundBankProvider).play(Sfx.win);
                  messenger.hideCurrentSnackBar();
                  onOpen(ref.read(diveProvider).refFor(depth));
                },
              )
            : null,
      ),
    );
}

/// One named band of the dive: a heading and the depths it covers.
///
/// A band is a single list item rather than a heading sliver plus a grid
/// sliver, because slivers have to be counted at build time and this list has
/// no count. The grid is laid out by hand for the same reason — it is a fixed
/// [kStratumSpan] of cards in three columns, so a column of rows is both
/// simpler and cheaper than nesting a scrollable.
class _DiveBand extends StatelessWidget {
  const _DiveBand({
    required this.band,
    required this.feed,
    required this.dive,
    required this.l10n,
    required this.devUnlockAll,
    required this.onOpen,
    required this.onRefused,
  });

  final int band;
  final LevelFeed feed;
  final DiveSnapshot dive;
  final L10n l10n;
  final bool devUnlockAll;
  final void Function(LevelRef) onOpen;
  final void Function(int depth) onRefused;

  static const int _columns = 3;

  @override
  Widget build(BuildContext context) {
    final first = band * kStratumSpan + 1;
    final last = first + kStratumSpan - 1;
    // Keep building past the bottom of this band, so scrolling on lands on
    // levels that are already there.
    feed.prefetch(last + 1, LevelFeed.lookAhead);

    final rows = (kStratumSpan + _columns - 1) ~/ _columns;
    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BandHeading(l10n.stratumName(band), '$first–$last'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                for (var row = 0; row < rows; row++) ...[
                  if (row > 0) const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var column = 0; column < _columns; column++) ...[
                        if (column > 0) const SizedBox(width: 12),
                        Expanded(
                          child: _slot(first + row * _columns + column, last),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slot(int depth, int last) {
    if (depth > last) return const AspectRatio(aspectRatio: 0.82);
    final unlocked = devUnlockAll || dive.isUnlocked(depth);
    final level = feed.peek(depth);
    final record = dive[depth];
    return AspectRatio(
      aspectRatio: 0.82,
      child: _LevelCard(
        badge: depth.toString().padLeft(2, '0'),
        // Null while it is still being built. The card shows a placeholder for
        // a frame or two rather than the list stalling on the planner.
        goal: level?.goal,
        caption: l10n.depthLabel(depth),
        bestMoves: record?.bestMoves,
        locked: !unlocked,
        movesLabel: l10n.bestMoves,
        onTap: unlocked
            ? () => onOpen(dive.refFor(depth))
            : () => onRefused(depth),
      ),
    );
  }
}

class _BandHeading extends StatelessWidget {
  const _BandHeading(this.title, this.trailing);

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Palette.brassBright,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Text(
            trailing,
            style: AppTheme.monoDigits.copyWith(
              fontSize: 12,
              color: Palette.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Palette.brassBright,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.count, required this.builder});

  final int count;
  final Widget Function(int index) builder;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => builder(index),
          childCount: count,
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.badge,
    required this.caption,
    required this.goal,
    required this.bestMoves,
    required this.locked,
    required this.movesLabel,
    required this.onTap,
  });

  final String badge;
  final String caption;

  /// The target, or null when there is nothing to show yet — either because
  /// it is deliberately withheld, as the tutorial withholds unreached lessons,
  /// or because it is still being built a frame or two behind the scroll.
  final Shape? goal;

  final int? bestMoves;

  /// Dimmed and wearing a lock. The dive still shows its target: seeing what
  /// is coming is the point of the list going on forever.
  final bool locked;

  final String Function(int) movesLabel;

  /// Null makes the card inert. The dive passes a refusal instead, so a locked
  /// card can say why rather than swallowing the tap.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final best = bestMoves;
    final cleared = best != null;
    final text = Theme.of(context).textTheme;

    return Opacity(
      opacity: locked ? 0.4 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
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
              border: Border.all(
                color: cleared ? Palette.brassDim : Palette.hairline,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      badge,
                      style: AppTheme.monoDigits.copyWith(
                        fontSize: 13,
                        color: cleared ? Palette.brassBright : Palette.inkFaint,
                      ),
                    ),
                    const Spacer(),
                    if (locked)
                      const Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: Palette.inkFaint,
                      )
                    else if (cleared)
                      const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Palette.brassBright,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: goal == null
                      ? const Center(
                          child: Icon(
                            Icons.help_outline_rounded,
                            size: 26,
                            color: Palette.inkFaint,
                          ),
                        )
                      : ShapeView(shape: goal!),
                ),
                const SizedBox(height: 6),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: cleared ? Palette.inkMuted : Palette.inkFaint,
                  ),
                ),
                if (best != null)
                  Text(
                    movesLabel(best),
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
