import 'package:flutter/material.dart';

import '../core/shape/shape.dart';

/// Colour and type foundations. The look is a dim machinist's workbench:
/// teal-slate steel with warm brass accents.
abstract final class Palette {
  static const backdropTop = Color(0xFF0C1317);
  static const backdropBottom = Color(0xFF141F25);

  static const panel = Color(0xFF17222A);
  static const panelRaised = Color(0xFF1D2A32);
  static const panelSunken = Color(0xFF0E171C);
  static const hairline = Color(0xFF27373F);
  static const hairlineBright = Color(0xFF3A4E58);

  static const brass = Color(0xFFD8A657);
  static const brassBright = Color(0xFFF0C87E);
  static const brassDim = Color(0xFF8A6B33);

  static const ink = Color(0xFFE8F0F4);
  static const inkMuted = Color(0xFF93A7B1);
  static const inkFaint = Color(0xFF5F7480);

  static const success = Color(0xFF4FB477);
  static const danger = Color(0xFFE05B4A);

  /// Flat fill colour for a piece.
  static Color piece(QuadColor color) => switch (color) {
        QuadColor.uncolored => const Color(0xFF93A5AE),
        QuadColor.red => const Color(0xFFE05B4A),
        QuadColor.green => const Color(0xFF4FB477),
        QuadColor.blue => const Color(0xFF4F8FE0),
        QuadColor.yellow => const Color(0xFFEFC050),
        QuadColor.purple => const Color(0xFFA272DD),
        QuadColor.cyan => const Color(0xFF45C2C9),
      };

  static String label(QuadColor color) => switch (color) {
        QuadColor.uncolored => 'Bare',
        QuadColor.red => 'Red',
        QuadColor.green => 'Green',
        QuadColor.blue => 'Blue',
        QuadColor.yellow => 'Yellow',
        QuadColor.purple => 'Purple',
        QuadColor.cyan => 'Cyan',
      };
}

abstract final class AppTheme {
  static const display = 'SpaceGrotesk';
  static const body = 'Inter';

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: Palette.brass,
      onPrimary: Color(0xFF201704),
      secondary: Palette.brassBright,
      surface: Palette.panel,
      onSurface: Palette.ink,
      error: Palette.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Palette.backdropTop,
      fontFamily: body,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: display,
          fontWeight: FontWeight.w700,
          fontSize: 46,
          letterSpacing: 6,
          color: Palette.ink,
        ),
        titleLarge: TextStyle(
          fontFamily: display,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          letterSpacing: 0.4,
          color: Palette.ink,
        ),
        titleMedium: TextStyle(
          fontFamily: display,
          fontWeight: FontWeight.w500,
          fontSize: 16,
          letterSpacing: 0.2,
          color: Palette.ink,
        ),
        labelLarge: TextStyle(
          fontFamily: display,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 1.6,
          color: Palette.ink,
        ),
        labelMedium: TextStyle(
          fontFamily: body,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 1.4,
          color: Palette.inkMuted,
        ),
        bodyMedium: TextStyle(
          fontFamily: body,
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 1.4,
          color: Palette.inkMuted,
        ),
        bodySmall: TextStyle(
          fontFamily: body,
          fontWeight: FontWeight.w400,
          fontSize: 12,
          color: Palette.inkFaint,
        ),
      ),
    );
  }

  /// Tabular digits for counters that must not jitter while animating.
  static const monoDigits = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
