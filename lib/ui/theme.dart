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
    QuadColor.orange => const Color(0xFFE8893A),
    QuadColor.magenta => const Color(0xFFE45AA0),
  };

  static String label(QuadColor color) => switch (color) {
    QuadColor.uncolored => 'Bare',
    QuadColor.red => 'Red',
    QuadColor.green => 'Green',
    QuadColor.blue => 'Blue',
    QuadColor.yellow => 'Yellow',
    QuadColor.purple => 'Purple',
    QuadColor.cyan => 'Cyan',
    QuadColor.orange => 'Orange',
    QuadColor.magenta => 'Magenta',
  };
}

abstract final class AppTheme {
  static const display = 'SpaceGrotesk';
  static const body = 'Inter';

  /// Inter first so Cyrillic (and other Inter scripts) never hit a CJK face.
  /// System faces after that cover CJK, Arabic and Devanagari.
  static const fallbacks = <String>[
    body,
    'PingFang SC',
    'Hiragino Sans GB',
    'Noto Sans SC',
    'Noto Sans CJK SC',
    'Hiragino Sans',
    'Yu Gothic',
    'Noto Sans JP',
    'Apple SD Gothic Neo',
    'Noto Sans KR',
    'Noto Naskh Arabic',
    'Geeza Pro',
    'Noto Sans Arabic',
    'Kohinoor Devanagari',
    'Noto Sans Devanagari',
    'Devanagari Sangam MN',
    'Noto Sans',
    'Segoe UI',
    'Roboto',
  ];

  static ThemeData build({
    bool wideTracking = true,
    bool useDisplayFace = true,
  }) {
    const scheme = ColorScheme.dark(
      primary: Palette.brass,
      onPrimary: Color(0xFF201704),
      secondary: Palette.brassBright,
      surface: Palette.panel,
      onSurface: Palette.ink,
      error: Palette.danger,
    );

    final titles = useDisplayFace ? display : body;
    final labelTracking = wideTracking ? 1.6 : 0.0;
    final overlineTracking = wideTracking ? 1.4 : 0.0;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Palette.backdropTop,
      fontFamily: body,
      fontFamilyFallback: fallbacks,
      splashFactory: InkSparkle.splashFactory,
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontFamily: display,
          fontFamilyFallback: fallbacks,
          fontWeight: FontWeight.w700,
          fontSize: 46,
          letterSpacing: 6,
          color: Palette.ink,
        ),
        titleLarge: TextStyle(
          fontFamily: titles,
          fontFamilyFallback: fallbacks,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          letterSpacing: useDisplayFace ? 0.4 : 0,
          color: Palette.ink,
        ),
        titleMedium: TextStyle(
          fontFamily: titles,
          fontFamilyFallback: fallbacks,
          fontWeight: FontWeight.w500,
          fontSize: 16,
          letterSpacing: useDisplayFace ? 0.2 : 0,
          color: Palette.ink,
        ),
        labelLarge: TextStyle(
          fontFamily: titles,
          fontFamilyFallback: fallbacks,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: labelTracking,
          color: Palette.ink,
        ),
        labelMedium: TextStyle(
          fontFamily: body,
          fontFamilyFallback: fallbacks,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: overlineTracking,
          color: Palette.inkMuted,
        ),
        bodyMedium: const TextStyle(
          fontFamily: body,
          fontFamilyFallback: fallbacks,
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 1.4,
          color: Palette.inkMuted,
        ),
        bodySmall: const TextStyle(
          fontFamily: body,
          fontFamilyFallback: fallbacks,
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
    fontFamilyFallback: fallbacks,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
