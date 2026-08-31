import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../audio/sfx.dart';
import '../../data/progress_store.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// The seed, where the player can actually see it.
///
/// It sits on the front page rather than in settings because it is not a
/// setting: it is which game you are playing. Yours was drawn for this device,
/// and typing in somebody else's is how two people climb the same ladder.
///
/// It shows from the first launch, before there is a ladder to grow, because
/// a number you have never seen is not one you would think to trade.
class SeedCard extends ConsumerWidget {
  const SeedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dive = ref.watch(diveProvider);
    final l10n = ref.watch(l10nProvider);
    // A borrowed seed is worth showing plainly — it explains why the ladder
    // stopped looking familiar.
    final borrowed = !dive.isHomeSeed;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('home-seed-card'),
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ref.read(soundBankProvider).play(Sfx.tap);
          showSeedSheet(context);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 7, 18, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: borrowed
                ? Palette.brass.withValues(alpha: 0.12)
                : Palette.panelSunken,
            border: Border.all(
              color: borrowed ? Palette.brassDim : Palette.hairline,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.seedLabel,
                style: AppTheme.monoDigits.copyWith(
                  fontSize: 8,
                  color: borrowed ? Palette.brassBright : Palette.inkMuted,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${dive.seed}',
                style: AppTheme.monoDigits.copyWith(
                  fontSize: 12,
                  height: 1.1,
                  color: borrowed ? Palette.brassBright : Palette.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showSeedSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (_) => const _SeedSheet(),
  );
}

class _SeedSheet extends ConsumerStatefulWidget {
  const _SeedSheet();

  @override
  ConsumerState<_SeedSheet> createState() => _SeedSheetState();
}

class _SeedSheetState extends ConsumerState<_SeedSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _controller.text = '${ref.read(diveProvider).seed}';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _apply(int seed) {
    _focus.unfocus();
    ref.read(soundBankProvider).play(Sfx.tap);
    ref.read(diveProvider.notifier).useSeed(seed);
    _controller.text = '$seed';
    setState(() => _copied = false);
  }

  Future<void> _copySeed() async {
    await Clipboard.setData(
      ClipboardData(text: '${ref.read(diveProvider).seed}'),
    );
    if (!mounted) return;
    ref.read(soundBankProvider).play(Sfx.tap);
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final dive = ref.watch(diveProvider);
    // Another route may have moved the seed while this was open.
    if (!_focus.hasFocus && _controller.text != '${dive.seed}') {
      _controller.text = '${dive.seed}';
    }

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
                Text(
                  l10n.seedLabel,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.seedBody,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('seed-field'),
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTheme.monoDigits.copyWith(
                    fontSize: 22,
                    color: Palette.ink,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.seedLabel,
                    helperText: l10n.seedHint,
                    suffixIcon: IconButton(
                      key: const Key('seed-copy'),
                      onPressed: _copySeed,
                      icon: Icon(
                        _copied ? Icons.check_rounded : Icons.copy_all_rounded,
                        size: 20,
                      ),
                      color: _copied ? Palette.success : Palette.inkMuted,
                      tooltip: _copied ? l10n.copied : l10n.copy,
                    ),
                  ),
                  onSubmitted: (value) {
                    final parsed = int.tryParse(value.trim());
                    _apply(
                      parsed == null || parsed <= 0 ? freshDiveSeed() : parsed,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ActionButton(
                        key: const Key('seed-random'),
                        label: l10n.seedRandom,
                        icon: Icons.casino_rounded,
                        expand: true,
                        onPressed: () => _apply(freshDiveSeed()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ActionButton(
                        key: const Key('seed-default'),
                        label: l10n.seedDefault,
                        icon: Icons.home_rounded,
                        expand: true,
                        onPressed: dive.isHomeSeed
                            ? null
                            : () => _apply(dive.homeSeed),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
