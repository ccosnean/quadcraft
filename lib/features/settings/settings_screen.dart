import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../audio/sfx.dart';
import '../../data/progress_store.dart';
import '../../debug/objectbox_inspector_launch_export.dart';
import '../../l10n/l10n.dart';
import '../../ui/grain_background.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const SettingsScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final muted = ref.watch(mutedProvider);
    final confetti = ref.watch(confettiProvider);
    final targetPreview = ref.watch(targetPreviewProvider);
    final language = ref.watch(languageProvider);
    final store = ref.watch(progressStoreProvider);
    final showInspector = canOpenObjectBoxInspector;

    return Scaffold(
      body: GrainBackground(
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
                      tooltip: l10n.settings,
                    ),
                    Expanded(
                      child: Text(
                        l10n.settings,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Overline(l10n.sound),
                      const SizedBox(height: 10),
                      Panel(
                        child: _ToggleRow(
                          title: l10n.sound,
                          subtitle: l10n.soundHint,
                          value: !muted,
                          onChanged: (_) =>
                              ref.read(mutedProvider.notifier).toggle(),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Overline(l10n.confettiLabel),
                      const SizedBox(height: 10),
                      Panel(
                        padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                l10n.confettiHint,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final option in ConfettiAmount.values)
                              _ChoiceRow(
                                key: Key('confetti-${option.name}'),
                                label: _confettiLabel(l10n, option),
                                selected: option == confetti,
                                onTap: () {
                                  if (option == confetti) return;
                                  ref.read(soundBankProvider).play(Sfx.tap);
                                  ref
                                      .read(confettiProvider.notifier)
                                      .set(option);
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Overline(l10n.targetPreviewLabel),
                      const SizedBox(height: 10),
                      Panel(
                        padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                l10n.targetPreviewHint,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final option in TargetPreviewMode.values)
                              _ChoiceRow(
                                key: Key('target-preview-${option.name}'),
                                label: _targetPreviewLabel(l10n, option),
                                selected: option == targetPreview,
                                onTap: () {
                                  if (option == targetPreview) return;
                                  ref.read(soundBankProvider).play(Sfx.tap);
                                  ref
                                      .read(targetPreviewProvider.notifier)
                                      .set(option);
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Overline(l10n.languageLabel),
                      const SizedBox(height: 10),
                      Panel(
                        padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                l10n.languageHint,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final option in AppLanguage.values)
                              _ChoiceRow(
                                key: Key('language-${option.code}'),
                                label: option.nativeName,
                                selected: option == language,
                                onTap: () {
                                  if (option == language) return;
                                  ref.read(soundBankProvider).play(Sfx.tap);
                                  ref
                                      .read(languageProvider.notifier)
                                      .set(option);
                                },
                              ),
                          ],
                        ),
                      ),
                      if (showInspector) ...[
                        const SizedBox(height: 22),
                        const Overline('Debug'),
                        const SizedBox(height: 10),
                        Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Browse and edit the ObjectBox store on this device.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 14),
                              ActionButton(
                                key: const Key('objectbox-inspector'),
                                label: 'ObjectBox inspector',
                                icon: Icons.bug_report_rounded,
                                expand: true,
                                onPressed: () =>
                                    openQuadcraftObjectBoxInspector(
                                      context,
                                      store,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Overline(l10n.resetGame, color: Palette.danger),
                      const SizedBox(height: 10),
                      Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.resetGameHint,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 14),
                            ActionButton(
                              key: const Key('reset-game'),
                              label: l10n.resetGame,
                              icon: Icons.delete_forever_rounded,
                              danger: true,
                              expand: true,
                              onPressed: () => _confirmReset(context, ref),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _confettiLabel(L10n l10n, ConfettiAmount amount) => switch (amount) {
  ConfettiAmount.full => l10n.confettiFull,
  ConfettiAmount.reduced => l10n.confettiReduced,
  ConfettiAmount.off => l10n.confettiOff,
};

String _targetPreviewLabel(L10n l10n, TargetPreviewMode mode) => switch (mode) {
  TargetPreviewMode.off => l10n.targetPreviewOff,
  TargetPreviewMode.auto => l10n.targetPreviewAuto,
  TargetPreviewMode.manual => l10n.targetPreviewManual,
};

Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => const _ResetDialog(),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final l10n = ref.read(l10nProvider);
  ref.read(progressProvider.notifier).resetProgress();
  ref.read(soundBankProvider).play(Sfx.tap);
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      backgroundColor: Palette.panelRaised,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Palette.hairline),
      ),
      content: Text(
        l10n.resetDone,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Palette.ink),
      ),
    ),
  );
  if (!context.mounted) return;
  final navigator = Navigator.of(context);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted && navigator.canPop()) navigator.pop();
  });
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          key: const Key('sound-toggle'),
          value: value,
          onChanged: onChanged,
          activeThumbColor: Palette.brassBright,
          activeTrackColor: Palette.brassDim,
          inactiveThumbColor: Palette.inkMuted,
          inactiveTrackColor: Palette.panelSunken,
        ),
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? Palette.brassBright : Palette.inkFaint,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? Palette.ink : Palette.inkMuted,
                  fontFamily: AppTheme.body,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three confirmations before progress is actually wiped.
class _ResetDialog extends ConsumerStatefulWidget {
  const _ResetDialog();

  @override
  ConsumerState<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends ConsumerState<_ResetDialog> {
  int _step = 0;
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final cleared = ref.watch(progressProvider).clearedCount;

    final title = switch (_step) {
      0 => l10n.resetStep1Title,
      1 => l10n.resetStep2Title(cleared),
      _ => l10n.resetStep3Title,
    };
    final body = switch (_step) {
      0 => l10n.resetStep1Body,
      1 => l10n.resetStep2Body,
      _ => l10n.resetStep3Body,
    };
    final confirm = switch (_step) {
      0 => l10n.continueAction,
      1 => l10n.continueAction,
      _ => l10n.eraseEverything,
    };
    final abort = _step == 2 ? l10n.keepProgress : l10n.cancel;
    final canConfirm = _step != 1 || _understood;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Overline('${_step + 1} / 3', color: Palette.danger),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
            if (_step == 1) ...[
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('reset-understand'),
                  onTap: () => setState(() => _understood = !_understood),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          _understood
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 22,
                          color: _understood
                              ? Palette.brassBright
                              : Palette.inkFaint,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.iUnderstand,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: _understood
                                      ? Palette.ink
                                      : Palette.inkMuted,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ActionButton(
              key: const Key('reset-step-confirm'),
              label: confirm,
              primary: _step < 2,
              danger: _step == 2,
              expand: true,
              onPressed: canConfirm
                  ? () {
                      if (_step < 2) {
                        setState(() => _step++);
                      } else {
                        Navigator.of(context).pop(true);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 10),
            ActionButton(
              key: const Key('reset-step-abort'),
              label: abort,
              expand: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
