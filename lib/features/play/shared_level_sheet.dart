import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../audio/sfx.dart';
import '../../core/level/level.dart';
import '../../core/level/level_catalog.dart';
import '../../core/share/share_code.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'play_screen.dart';

/// Whether a code points at a rung of this player's own ladder or somebody
/// else's.
///
/// A code is usually a stranger's, but not always: players trade seeds, and a
/// depth you have already reached on the seed you are diving is your own level
/// however it arrived. Anything else — another seed, or a depth further down
/// than you have opened — is a challenge, so a code can never be used to skip
/// the ladder and bank a score at depth 400.
LevelRef resolveSharedRef(
  SharedLevel shared, {
  required int diveSeed,
  required int diveDepth,
  required bool isCampaignUnlocked,
  bool isLadderOpen = true,
}) {
  final ref = shared.ref;
  final isOwn = switch (ref.kind) {
    LevelKind.campaign => isCampaignUnlocked,
    LevelKind.endless =>
      isLadderOpen && ref.seed == diveSeed && ref.number <= diveDepth,
  };
  return isOwn ? ref.asOwn() : ref.asChallenge();
}

/// Asks before re-seeding the run, because adopting a seed drops the depth
/// scores of the one in progress.
Future<bool> confirmDiveThisSeed(BuildContext context, WidgetRef ref) async {
  final l10n = ref.read(l10nProvider);
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.diveThisSeed,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.diveThisSeedBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ActionButton(
                    label: l10n.cancel,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ActionButton(
                    key: const Key('dive-seed-confirm'),
                    label: l10n.continueAction,
                    primary: true,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

/// Opens the sheet that turns a code somebody sent into a playable level.
Future<void> showSharedLevelSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (_) => const _SharedLevelSheet(),
  );
}

class _SharedLevelSheet extends ConsumerStatefulWidget {
  const _SharedLevelSheet();

  @override
  ConsumerState<_SharedLevelSheet> createState() => _SharedLevelSheetState();
}

class _SharedLevelSheetState extends ConsumerState<_SharedLevelSheet> {
  final TextEditingController _controller = TextEditingController();
  SharedLevel? _shared;

  /// The code was typed but does not name a level. Held apart from [_shared]
  /// so an empty field says nothing rather than accusing the player of a
  /// mistake they have not made yet.
  bool _rejected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final parsed = ShareCode.parse(raw);
    setState(() {
      _shared = parsed;
      _rejected = parsed == null && raw.trim().isNotEmpty;
    });
  }

  void _open() {
    final shared = _shared;
    if (shared == null) return;
    final dive = ref.read(diveProvider);
    final progress = ref.read(progressProvider);
    final target = resolveSharedRef(
      shared,
      diveSeed: dive.seed,
      diveDepth: dive.depth,
      isCampaignUnlocked: progress.isUnlocked(shared.ref.number),
      // Before the lessons are done there is no ladder of your own for a
      // code to be a rung of, so anything generated is somebody else's.
      isLadderOpen: progress.diveOpen,
    );

    ref.read(soundBankProvider).play(Sfx.tap);
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(PlayScreen.route(target, movesToBeat: shared.movesToBeat));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final text = Theme.of(context).textTheme;
    final shared = _shared;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Palette.hairlineBright,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(l10n.playShared, style: text.titleLarge),
                const SizedBox(height: 4),
                Text(l10n.sharedNotCounted, style: text.bodySmall),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('share-code-field'),
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: AppTheme.monoDigits.copyWith(
                    fontSize: 20,
                    color: Palette.ink,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.shareCodeHint,
                    errorText: _rejected ? l10n.shareCodeBad : null,
                  ),
                  onChanged: _onChanged,
                  onSubmitted: (_) => _open(),
                ),
                const SizedBox(height: 16),
                if (shared != null) _SharedPreview(shared: shared),
                const SizedBox(height: 16),
                ActionButton(
                  key: const Key('share-code-open'),
                  label: l10n.start,
                  icon: Icons.play_arrow_rounded,
                  primary: true,
                  expand: true,
                  onPressed: shared == null ? null : _open,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the code turned out to name. Shown before the level opens because the
/// target is the only real check on a mistyped code: a wrong digit lands on a
/// perfectly valid puzzle, and the shape here is what the sender's picture
/// should match.
class _SharedPreview extends ConsumerWidget {
  const _SharedPreview({required this.shared});

  final SharedLevel shared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final level = levelFor(shared.ref);
    final beat = shared.movesToBeat;

    return Panel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Plate(
            radius: 18,
            padding: const EdgeInsets.all(8),
            child: ShapeView(shape: level.goal, size: 56),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.levelTitle(level),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.levelSection(level),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (beat != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.movesToBeat(beat),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Palette.brassBright),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
