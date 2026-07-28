import 'package:flutter/material.dart';

import 'ui/boot_screen.dart';
import 'ui/tokens.g.dart';

void main() {
  runApp(const KiBoardApp());
}

class KiBoardApp extends StatelessWidget {
  const KiBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KiBoard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F10),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(DeckTokens.accent), brightness: Brightness.dark),
      ),
      home: const BootScreen(),
    );
  }
}
