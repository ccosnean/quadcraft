import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_providers.dart';
import '../../core/level/level.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Pixel size of the exported share image (portrait, story-friendly).
const Size kShareCardSize = Size(1080, 1350);

/// Branded score card rendered into a PNG for sharing.
class ShareCard extends ConsumerWidget {
  const ShareCard({
    super.key,
    required this.level,
    required this.moves,
    this.isNewBest = false,
  });

  final Level level;
  final int moves;
  final bool isNewBest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final track = ref.watch(languageProvider).usesWideTracking;
    return ColoredBox(
      color: Palette.backdropTop,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF101820),
                  Palette.backdropTop,
                  Color(0xFF0A1014),
                ],
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.15),
            child: Container(
              width: 520,
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Palette.brass.withValues(alpha: 0.16),
                    Palette.brass.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 88, 72, 72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'QUADCRAFT',
                  textAlign: TextAlign.center,
                  style: AppTheme.monoDigits.copyWith(
                    fontSize: 42,
                    letterSpacing: 10,
                    color: Palette.brassBright,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.levelNumber(level.number).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 22,
                    letterSpacing: track ? 4 : 0,
                    color: Palette.inkFaint,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  level.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTheme.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 40,
                    letterSpacing: 0.4,
                    color: Palette.ink,
                  ),
                ),
                const Spacer(),
                Center(
                  child: Container(
                    width: 520,
                    height: 520,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(48),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Palette.panelSunken, Color(0xFF070C10)],
                      ),
                      border: Border.all(color: Palette.brassDim, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 40,
                          offset: const Offset(0, 22),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(48),
                    child: ShapeView(shape: level.goal, size: 424),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: Palette.panelSunken.withValues(alpha: 0.92),
                    border: Border.all(
                      color: isNewBest ? Palette.brassDim : Palette.hairline,
                      width: 1.6,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.moves.toUpperCase(),
                              style: TextStyle(
                                fontFamily: AppTheme.body,
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                letterSpacing: track ? 3 : 0,
                                color: Palette.inkFaint,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$moves',
                              style: AppTheme.monoDigits.copyWith(
                                fontSize: 72,
                                height: 1,
                                color: Palette.brassBright,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isNewBest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Palette.brass.withValues(alpha: 0.18),
                            border: Border.all(color: Palette.brassDim),
                          ),
                          child: Text(
                            l10n.newBest.toUpperCase(),
                            style: TextStyle(
                              fontFamily: track
                                  ? AppTheme.display
                                  : AppTheme.body,
                              fontFamilyFallback: AppTheme.fallbacks,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              letterSpacing: track ? 2 : 0,
                              color: Palette.brassBright,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.thinkYouCanBeat(moves),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTheme.body,
                    fontWeight: FontWeight.w400,
                    fontSize: 24,
                    color: Palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a preview of the share card, then the platform share sheet.
Future<void> showShareScoreSheet({
  required BuildContext context,
  required Level level,
  required int moves,
  bool isNewBest = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (_) =>
        _ShareScoreSheet(level: level, moves: moves, isNewBest: isNewBest),
  );
}

class _ShareScoreSheet extends ConsumerStatefulWidget {
  const _ShareScoreSheet({
    required this.level,
    required this.moves,
    required this.isNewBest,
  });

  final Level level;
  final int moves;
  final bool isNewBest;

  @override
  ConsumerState<_ShareScoreSheet> createState() => _ShareScoreSheetState();
}

class _ShareScoreSheetState extends ConsumerState<_ShareScoreSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _busy = false;
  String? _error;

  Future<void> _share() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Share card is not ready yet.');
      }

      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('Could not encode the share card.');
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(
          dir.path,
          'quadcraft-L${widget.level.number}-${widget.moves}moves.png',
        ),
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: ref
              .read(l10nProvider)
              .shareCaption(
                widget.level.number,
                widget.level.name,
                widget.moves,
              ),
          subject: 'Quadcraft · ${widget.level.name}',
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = ref.read(l10nProvider).shareFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    final previewW = (MediaQuery.sizeOf(context).width - 48).clamp(
      240.0,
      360.0,
    );
    final previewH = previewW * (kShareCardSize.height / kShareCardSize.width);

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
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
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Palette.hairlineBright,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.shareScore,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.shareScoreHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Center(
                  child: SizedBox(
                    width: previewW,
                    height: previewH,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox(
                          width: kShareCardSize.width,
                          height: kShareCardSize.height,
                          child: RepaintBoundary(
                            key: _cardKey,
                            child: ShareCard(
                              level: widget.level,
                              moves: widget.moves,
                              isNewBest: widget.isNewBest,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Palette.danger),
                ),
              ],
              const SizedBox(height: 16),
              ActionButton(
                label: _busy ? l10n.preparing : l10n.shareImage,
                icon: Icons.ios_share_rounded,
                primary: true,
                expand: true,
                onPressed: _busy ? null : _share,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
