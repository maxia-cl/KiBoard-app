import 'package:flutter/material.dart';

/// KiBoard's brand palette, taken from the v1 logo: mahjong tiles on paper.
///
/// This is NOT the deck's palette. `tokens.g.dart` is generated from `deck-tokens.json` and paints
/// the drawn device — a dark bezel and dark keys, because the device has to read as hardware. These
/// colours paint everything that is the *product* rather than the device: the splash, and anything
/// added later that speaks in KiBoard's voice instead of the key pad's.
///
/// The one they share is the red: `accent` here and `DeckTokens.accent` are both `#B22420`, the
/// tile "d" of the logo. If one ever moves, the other has to move with it.
class Brand {
  final Color paper;
  final Color tile;
  final Color tileBorder;
  final Color ink;
  final Color inkSoft;
  final Color accent;
  final Color onAccent;

  const Brand({
    required this.paper,
    required this.tile,
    required this.tileBorder,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.onAccent,
  });

  static const light = Brand(
    paper: Color(0xFFF7F2E9),
    tile: Color(0xFFFFFDF9),
    tileBorder: Color(0xFFE7DCC8),
    ink: Color(0xFF2A2622),
    inkSoft: Color(0xFF8A8178),
    accent: Color(0xFFB22420),
    onAccent: Color(0xFFFDF6EE),
  );

  static const dark = Brand(
    paper: Color(0xFF141210),
    tile: Color(0xFF211E1A),
    tileBorder: Color(0xFF332E27),
    ink: Color(0xFFEDE6DB),
    inkSoft: Color(0xFF988F82),
    accent: Color(0xFFE0564E),
    onAccent: Color(0xFF1A0E0D),
  );

  /// The app runs on a fixed dark theme (see `main.dart`), so this is `dark` in practice today.
  /// It still asks rather than hardcoding, because the light half exists and the day the app
  /// follows the system this is the only line that has to be right. The Android launch theme is
  /// pinned dark to match — a system splash that followed the phone showed a cream screen in front
  /// of a dark app.
  static Brand of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;

  /// The logo file that reads on this brightness — the mark is dark ink on paper, so it needs its
  /// own light-on-dark version rather than a tint.
  static String logoAsset(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? 'assets/brand/logo_dark.png'
      : 'assets/brand/logo.png';
}
