import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';
import 'ui/theme.dart';

class QuadcraftApp extends StatelessWidget {
  const QuadcraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quadcraft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const HomeScreen(),
    );
  }
}
