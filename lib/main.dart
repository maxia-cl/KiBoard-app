import 'package:flutter/material.dart';

import 'ui/pair/discover_screen.dart';
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
      home: DiscoverScreen(),
    );
  }
}

/// R11-style watermark, updated for F2: discovery, pairing AND the deck are real now — the app
/// talks to a live host over protocol v2. What is still missing is F3's polish (reconnection
/// states, key confirmation, haptics, i18n) and F4's app catalogue, so `launch:`/`focus:` keys
/// answer `unknown_action` for the moment.
class _MockWatermark extends StatelessWidget {
  const _MockWatermark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(DeckTokens.accent),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: const Text(
        'F2 · LIVE HOST · NO RECONNECTION YET, NO APP CATALOGUE',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600),
      ),
    );
  }
}
