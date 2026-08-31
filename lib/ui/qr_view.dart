import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import 'theme.dart';

/// A QR code painted the same way as everything else in the game.
///
/// Drawn rather than pulled from a widget library so it lands on the share
/// card as plain vector output, which is what the PNG export captures.
///
/// It is painted dark-on-light on its own tile even though the card is dark:
/// inverted codes are readable by some scanners and not others, and a share
/// image is only worth making if every phone that meets it can open it.
class QrView extends StatefulWidget {
  const QrView({
    super.key,
    required this.data,
    this.size = 160,
    this.dark = Palette.backdropTop,
    this.light = const Color(0xFFF3F7F9),
    this.radius = 12,
  });

  final String data;
  final double size;
  final Color dark;
  final Color light;
  final double radius;

  @override
  State<QrView> createState() => _QrViewState();
}

class _QrViewState extends State<QrView> {
  late QrImage _image = _encode(widget.data);

  @override
  void didUpdateWidget(QrView old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _image = _encode(widget.data);
  }

  /// Quartile correction: these codes are small on the card and end up
  /// photographed off a screen, so buy back some robustness for a few modules.
  static QrImage _encode(String data) => QrImage(
    QrCode(
      payload: QrPayload.fromString(data),
      errorCorrectLevel: QrErrorCorrectLevel.quartile,
    ),
  );

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(widget.size),
    isComplex: true,
    painter: _QrPainter(
      image: _image,
      dark: widget.dark,
      light: widget.light,
      radius: widget.radius,
    ),
  );
}

class _QrPainter extends CustomPainter {
  _QrPainter({
    required this.image,
    required this.dark,
    required this.light,
    required this.radius,
  });

  final QrImage image;
  final Color dark;
  final Color light;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, side, side),
        Radius.circular(radius),
      ),
      Paint()..color = light,
    );

    // The quiet zone the spec asks for, scaled to the tile rather than fixed,
    // so the code stays scannable at any size the card is rendered at.
    final quiet = side * 0.075;
    final module = (side - quiet * 2) / image.moduleCount;
    final paint = Paint()
      ..color = dark
      ..isAntiAlias = false;

    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            quiet + col * module,
            quiet + row * module,
            // A hair of overlap: neighbouring modules must not show a seam
            // once the card is downscaled by whatever app it is opened in.
            module + 0.5,
            module + 0.5,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) =>
      old.image != image ||
      old.dark != dark ||
      old.light != light ||
      old.radius != radius;
}
