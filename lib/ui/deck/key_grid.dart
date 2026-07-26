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
