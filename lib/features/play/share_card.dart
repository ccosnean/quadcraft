import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_providers.dart';
import '../../audio/sfx.dart';
import '../../core/level/level.dart';
import '../../core/share/share_code.dart';
import '../../l10n/l10n.dart';
import '../../ui/qr_view.dart';
import '../../ui/shape_painter.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Pixel size of the exported share image (portrait, story-friendly).
const Size kShareCardSize = Size(1080, 1350);

/// Line above the title on the share card: the chapter for a campaign level,
/// the band of the dive for a generated one.
String _shareOverline(L10n l10n, Level level) => switch (level.kind) {
  LevelKind.campaign => l10n.tutorialNumber(level.number),
  LevelKind.endless => l10n.stratumName(level.stratum),
};

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
                  _shareOverline(l10n, level).toUpperCase(),
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
                  l10n.levelTitle(level),
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
                  padding: const EdgeInsets.fromLTRB(36, 26, 26, 26),
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
                          mainAxisSize: MainAxisSize.min,
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
                            if (isNewBest) ...[
                              const SizedBox(height: 14),
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      _ShareTag(level: level, moves: moves, l10n: l10n),
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

/// The half of the card that is machine-readable: the exact level, as a code
/// a friend can type and a QR their camera can take straight off the screen.
///
/// Both carry the same thing, because a share image outlives whatever we can
/// resolve for it — a scan opens the level where there is a host to open it
/// on, and the printed code below always works by hand.
class _ShareTag extends StatelessWidget {
  const _ShareTag({
    required this.level,
    required this.moves,
    required this.l10n,
  });

  final Level level;
  final int moves;
  final L10n l10n;

  static const double _side = 200;

  @override
  Widget build(BuildContext context) {
    final ref = level.ref;
    return SizedBox(
      width: _side,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrView(
            data: ShareCode.payload(ref, moves: moves),
            size: _side,
            radius: 16,
          ),
          const SizedBox(height: 10),
          Text(
            ShareCode.encode(ref, moves: moves),
            maxLines: 1,
            style: AppTheme.monoDigits.copyWith(
              fontSize: 24,
              height: 1,
              color: Palette.brassBright,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.scanToPlay,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontFamily: AppTheme.body,
              fontFamilyFallback: AppTheme.fallbacks,
              fontWeight: FontWeight.w400,
              fontSize: 17,
              height: 1.25,
              color: Palette.inkFaint,
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
  bool _copied = false;
  String? _error;

  /// What a friend needs to open this exact level: the link once there is a
  /// host for one, the typed code until then.
  String get _handoff =>
      ShareCode.payload(widget.level.ref, moves: widget.moves);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _handoff));
    if (!mounted) return;
    ref.read(soundBankProvider).play(Sfx.tap);
    setState(() => _copied = true);
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final l10n = ref.read(l10nProvider);
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
          widget.level.kind == LevelKind.endless
              ? 'quadcraft-depth${widget.level.number}-'
                    '${widget.moves}moves.png'
              : 'quadcraft-L${widget.level.number}-${widget.moves}moves.png',
        ),
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

      // Someone reading the message rather than the picture still needs a way
      // in: the link where there is one, the typed code where there is not.
      final handoff =
          ShareCode.link(widget.level.ref, moves: widget.moves) != null
          ? _handoff
          : '${l10n.playShared}: $_handoff';

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text:
              '${l10n.shareCaption(widget.level.number, l10n.levelTitle(widget.level), widget.moves)}'
              '\n\n$handoff',
          subject: 'Quadcraft · ${l10n.levelTitle(widget.level)}',
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
              const SizedBox(height: 14),
              // The picture is the thing worth posting, but it cannot be
              // pasted into a chat window, so the code goes out on its own too.
              Text(
                ShareCode.encode(widget.level.ref, moves: widget.moves),
                textAlign: TextAlign.center,
                style: AppTheme.monoDigits.copyWith(
                  fontSize: 18,
                  color: Palette.brassBright,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      key: const Key('share-copy'),
                      label: _copied ? l10n.copied : l10n.copy,
                      icon: _copied
                          ? Icons.check_rounded
                          : Icons.copy_all_rounded,
                      expand: true,
                      onPressed: _copy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ActionButton(
                      key: const Key('share-image'),
                      label: _busy ? l10n.preparing : l10n.shareImage,
                      icon: Icons.ios_share_rounded,
                      primary: true,
                      expand: true,
                      onPressed: _busy ? null : _share,
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
