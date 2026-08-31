import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/app_providers.dart';
import 'package:quadcraft/audio/sfx.dart';
import 'package:quadcraft/core/level/level.dart';
import 'package:quadcraft/core/level/level_catalog.dart';
import 'package:quadcraft/data/progress_store.dart';
import 'package:quadcraft/core/level/level.dart' show LevelRef;
import 'package:quadcraft/features/play/share_card.dart';
import 'package:quadcraft/ui/qr_view.dart';
import 'package:quadcraft/ui/theme.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, LevelRef ref, int moves) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressStoreProvider.overrideWithValue(MemoryProgressStore()),
          soundBankProvider.overrideWithValue(SoundBank.silent()),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Center(
            child: SizedBox(
              width: kShareCardSize.width,
              height: kShareCardSize.height,
              child: ShareCard(level: levelFor(ref), moves: moves),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a generated level ships its code on the card', (tester) async {
    tester.view.physicalSize = kShareCardSize * 1.2;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpCard(tester, LevelRef.endless(seed: 4242, number: 3), 14);

    expect(find.text('4242-3-14'), findsOneWidget);
    expect(find.text('Scan to play this level'), findsOneWidget);
    // The QR has to carry the same level the printed code does, or the two
    // halves of the card disagree about which puzzle this is.
    expect(tester.widget<QrView>(find.byType(QrView)).data, '4242-3-14');
  });

  testWidgets('a campaign level ships one too', (tester) async {
    tester.view.physicalSize = kShareCardSize * 1.2;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpCard(tester, const LevelRef.campaign(2), 5);

    expect(find.text('L2-5'), findsOneWidget);
    expect(tester.widget<QrView>(find.byType(QrView)).data, 'L2-5');
  });

  testWidgets('the code can be copied instead of the picture', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressStoreProvider.overrideWithValue(MemoryProgressStore()),
          soundBankProvider.overrideWithValue(SoundBank.silent()),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showShareScoreSheet(
                  context: context,
                  level: levelFor(LevelRef.endless(seed: 4242, number: 3)),
                  moves: 14,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('4242-3-14'), findsWidgets);
    await tester.tap(find.byKey(const Key('share-copy')));
    await tester.pumpAndSettle();

    // With no host to point at, what travels is the code itself.
    expect(copied, ['4242-3-14']);
    expect(find.text('COPIED'), findsOneWidget);
  });
}
