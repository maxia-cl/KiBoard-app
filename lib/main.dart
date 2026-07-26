import 'package:flutter/material.dart';

import 'mock/mock_discovery.dart';
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
      home: DiscoverScreen(discovery: MockDiscovery()),
    );
  }
}

/// R11: a visible watermark while `MockLayoutSource`/`MockDiscovery` are active, so a convincing
/// mock-up never gets mistaken for a working build. Falls away by itself once F1/F3 wire up the
/// real sources — there is no separate flag to remember to flip.
class _MockWatermark extends StatelessWidget {
  const _MockWatermark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(DeckTokens.accent),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: const Text(
        'MOCK-UP · PHASE FP · NO REAL HOST, NOTHING EXECUTES',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600),
      ),
    );
  }
}
