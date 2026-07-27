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
      builder: (context, child) => Column(
        children: [const _MockWatermark(), Expanded(child: child ?? const SizedBox.shrink())],
      ),
      home: const BootScreen(),
    );
  }
}

/// R11-style watermark. F3 in progress: the session now persists across launches and reconnects
/// on its own, and auto mode follows the foreground app for real. Still missing before this can
/// ship: i18n (the catalogue is Spanish-only on the wire), the trackpad and dictation ported from
/// v1, and F4's app catalogue — until that lands, `launch:`/`focus:` keys answer `unknown_action`.
class _MockWatermark extends StatelessWidget {
  const _MockWatermark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(DeckTokens.accent),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: const Text(
        'F3 · LIVE HOST · NO i18n, NO TRACKPAD, NO APP CATALOGUE',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600),
      ),
    );
  }
}
