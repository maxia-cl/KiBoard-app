import 'package:flutter/material.dart';

import '../../model/deck.dart';
import '../tokens.g.dart';
import 'key_widget.dart';

/// The fixed, non-scrolling grid inside the bezel (§3.1: "Physical grid, no scrolling — what
/// does not fit moves to another page"). `keys` must already be dense (length == grid.capacity).
class KeyGrid extends StatelessWidget {
  final Grid grid;
  final List<DeckKey> keys;
  final double keySize;
  final void Function(int pos, String press)? onKeyPress;

  const KeyGrid({super.key, required this.grid, required this.keys, required this.keySize, this.onKeyPress});

  static double gapFor(double keySize) => keySize * DeckTokens.keyGapRatioOfSide;
  static double widthFor(Grid grid, double keySize) =>
      grid.cols * keySize + (grid.cols - 1) * gapFor(keySize);
  static double heightFor(Grid grid, double keySize) =>
      grid.rows * keySize + (grid.rows - 1) * gapFor(keySize);

  /// The largest key that fits BOTH dimensions of the space available.
  ///
  /// Sizing off the width alone overflows the moment the screen is wider than it is tall — which
  /// is not an edge case: a key pad is a landscape device, and a phone turned sideways is the
  /// natural way to hold it. Bezel padding is subtracted by the caller.
  static double sizeToFit(Grid grid, double maxWidth, double maxHeight) {
    const gapRatio = DeckTokens.keyGapRatioOfSide;
    final byWidth = maxWidth / (grid.cols + (grid.cols - 1) * gapRatio);
    final byHeight = maxHeight / (grid.rows + (grid.rows - 1) * gapRatio);
    // Floor of 24 rather than 40: on a short landscape screen a small key still beats a broken
    // layout, and clamping above what fits is what produced the overflow in the first place.
    return (byWidth < byHeight ? byWidth : byHeight).clamp(24.0, 96.0);
  }

  @override
  Widget build(BuildContext context) {
    final gap = gapFor(keySize);
    return SizedBox(
      width: widthFor(grid, keySize),
      height: heightFor(grid, keySize),
      child: GridView.count(
        crossAxisCount: grid.cols,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        childAspectRatio: 1,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final key in keys)
            KeyWidget(keyData: key, size: keySize, onPress: (p) => onKeyPress?.call(key.pos, p)),
        ],
      ),
    );
  }
}
