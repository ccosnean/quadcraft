import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/shape/shape.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/features/play/tray_strip.dart';
import 'package:quadcraft/ui/theme.dart';

void main() {
  // Enough blueprints that the row cannot fit in a narrow phone width,
  // reproducing the overflow the tray has to absorb by scrolling rather
  // than by spilling past its own card.
  const forms = ['C', 'S', 'T', 'W', 'P', 'L'];
  const colors = ['u', 'r', 'g', 'b', 'y', 'p', 'c', 'o'];
  final manyShapes = [
    for (var i = 0; i < 8; i++)
      Shape.parse('${forms[i % forms.length]}${colors[i]}/-/-/-'),
  ];

  Widget host(Widget child) => ProviderScope(
    overrides: [
      progressStoreProvider.overrideWithValue(MemoryProgressStore()),
      soundBankProvider.overrideWithValue(SoundBank.silent()),
    ],
    child: MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(body: SizedBox(width: 320, child: child)),
    ),
  );

  testWidgets('an overflowing tray scrolls instead of spilling past its card', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        TrayStrip(
          shapes: manyShapes,
          colors: const [],
          onPlaceShape: (_, _) {},
          onPaint: (_, _) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Regression: this row used to opt out of clipping (`Clip.none`), so a
    // blueprint that only partly fit inside the 320-wide card painted its
    // full, uncut width past the panel's rounded edge instead of being
    // cropped by the row's own viewport.
    for (final list in tester.widgetList<ListView>(find.byType(ListView))) {
      expect(
        list.clipBehavior,
        isNot(Clip.none),
        reason:
            'a horizontally scrolling row must clip at its own bounds, or an '
            'overflowing chip paints outside the tray panel instead of just '
            'being scrolled past',
      );
    }

    // The row itself must stay within the width it was given — nothing about
    // the fix should let the tray card grow past its host.
    final panelWidth = tester.getSize(find.byType(TrayStrip)).width;
    expect(panelWidth, lessThanOrEqualTo(320));
  });
}
