import 'dart:math' as math;

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

  /// Positions the host has just confirmed with `key_result` ok — painted lit (§3.1).
  final Set<int> confirmed;

  const KeyGrid({
    super.key,
    required this.grid,
    required this.keys,
    required this.keySize,
    this.onKeyPress,
    this.confirmed = const {},
  });

  static double gapFor(double keySize) => keySize * DeckTokens.keyGapRatioOfSide;
  static double widthFor(Grid grid, double keySize) =>
      grid.cols * keySize + (grid.cols - 1) * gapFor(keySize);
  static double heightFor(Grid grid, double keySize) =>
      grid.rows * keySize + (grid.rows - 1) * gapFor(keySize);

  /// The key size for this DEVICE, deliberately independent of how it is being held.
  ///
  /// Rotating must not resize the keys: a key pad is hit from muscle memory, and a target that
  /// changes size when the phone turns is a different target. Sizing from the space actually
  /// available cannot deliver that — the system bars fall on the height in both orientations, so
  /// the usable box is not a transpose of itself.
  ///
  /// So the size comes from `shortestSide`/`longestSide`, which do not change when the device
  /// rotates, minus a reserve big enough to cover the shell on EITHER axis: system insets, the top
  /// bar, the bezel padding and the page dots. Being generous here costs a few pixels of key; not
  /// being generous enough costs an overflow, so [sizeToFit] still caps the result against the
  /// space really on offer.
  static double sizeForDevice(Size screen, Grid grid) {
    const gapRatio = DeckTokens.keyGapRatioOfSide;
    final small = math.min(grid.rows, grid.cols);
    final big = math.max(grid.rows, grid.cols);
    double fit(double space, int n) => space / (n + (n - 1) * gapRatio);
    return math.max(
      24.0,
      math.min(
        fit(screen.shortestSide - _shellReserve, small),
        fit(screen.longestSide - _shellReserve, big),
      ),
    );
  }

  /// Worst-case space the shell takes along one axis, across both orientations: system insets, the
  /// top bar, the bezel's padding and the page dots.
  ///
  /// MEASURED, not estimated. Too small a reserve and the safety cap in the caller bites —
  /// differently per orientation, which is precisely the resize this is meant to prevent. If a
  /// future change grows the shell, the caller's `CAPPED BY BOX` trace says so out loud.
  ///
  /// Was 150 while the bar ran across the top in BOTH orientations, costing 139 logical pixels of
  /// height sideways and 199 upright against 90 and 56 of width. Sideways it then went down the
  /// side, and after that the page dots followed it, the bezel padding went to 6/6 and the outer
  /// margin to nothing — so what is left on the height sideways is the padding and the system
  /// insets, and little else. Re-measure on the device after touching the shell; the number below
  /// is what the trace reported, not what the arithmetic predicted.
  static const _shellReserve = 75.0;

  /// The largest key that fits BOTH dimensions of the space available.
  ///
  /// Sizing off the width alone overflows the moment the screen is wider than it is tall — which
  /// is not an edge case: a key pad is a landscape device, and a phone turned sideways is the
  /// natural way to hold it. Bezel padding is subtracted by the caller.
  static double sizeToFit(Grid grid, double maxWidth, double maxHeight) {
    const gapRatio = DeckTokens.keyGapRatioOfSide;
    final byWidth = maxWidth / (grid.cols + (grid.cols - 1) * gapRatio);
    final byHeight = maxHeight / (grid.rows + (grid.rows - 1) * gapRatio);
    // Floor of 24 rather than 40: on a short screen a small key still beats a broken layout, and
    // clamping above what fits is what produced the overflow in the first place.
    //
    // No UPPER bound. `key.sizePx` (72) is the size the visual language is drawn at, not a cap:
    // capping there left the pad as a small patch in the middle of a big screen. The device is
    // supposed to be the screen.
    return math.max(24.0, byWidth < byHeight ? byWidth : byHeight);
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
            KeyWidget(
              keyData: key,
              size: keySize,
              confirmed: confirmed.contains(key.pos),
              onPress: (p) => onKeyPress?.call(key.pos, p),
            ),
        ],
      ),
    );
  }
}
