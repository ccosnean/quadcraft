import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadcraft/l10n/l10n.dart';
import 'package:quadcraft/ui/theme.dart';
import 'package:quadcraft/ui/widgets.dart';

void main() {
  testWidgets('win-row action buttons fit every language on a phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final language in AppLanguage.values) {
      final l10n = L10n(language);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(
            wideTracking: language.usesWideTracking,
            useDisplayFace: language.usesDisplayFace,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      label: l10n.replay,
                      icon: Icons.refresh_rounded,
                      expand: true,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      label: l10n.nextLevel,
                      icon: Icons.arrow_forward_rounded,
                      primary: true,
                      expand: true,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow in ${language.code}',
      );
    }
  });
}
