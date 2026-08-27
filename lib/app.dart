import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'features/home/home_screen.dart';
import 'l10n/l10n.dart';
import 'ui/theme.dart';

class QuadcraftApp extends ConsumerWidget {
  const QuadcraftApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    return MaterialApp(
      title: 'Quadcraft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(
        wideTracking: language.usesWideTracking,
        useDisplayFace: language.usesDisplayFace,
      ),
      locale: language.locale,
      supportedLocales: AppLanguage.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
