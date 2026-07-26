import 'package:flutter/material.dart';

import '../tokens.g.dart';

/// The physical shell (§3.0): matte dark bezel, wider bottom padding, engraved logo. Governs both
/// the deck screen and the window switcher (§3.5) — same bezel, same key, same pagination.
class DeviceBezel extends StatelessWidget {
  final double gridWidth;
  final double gridHeight;
  final Widget child;
  final int pageCount;
  final int currentPage;

  const DeviceBezel({
    super.key,
    required this.gridWidth,
    required this.gridHeight,
    required this.child,
    this.pageCount = 1,
    this.currentPage = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(DeckTokens.bezelGradientFrom), Color(DeckTokens.bezelGradientTo)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(DeckTokens.bezelCornerRadiusPx),
      ),
      padding: const EdgeInsets.fromLTRB(
        DeckTokens.bezelPaddingSidePx,
        DeckTokens.bezelPaddingTopPx,
        DeckTokens.bezelPaddingSidePx,
        DeckTokens.bezelPaddingBottomPx,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: gridWidth, height: gridHeight, child: child),
          if (pageCount > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < pageCount; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == currentPage
                          ? const Color(DeckTokens.pageDotActive)
                          : const Color(DeckTokens.pageDotInactive),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            DeckTokens.bezelLogoText,
            style: TextStyle(color: Color(DeckTokens.textSecondary), fontSize: 11, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}
