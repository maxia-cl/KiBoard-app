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

  /// Positions waiting for the app they opened to appear (see `KeyWidget.launching`).
  final Set<int> launching;

  /// Cells to leave blank BEFORE the first key. See the note in `build`.
  final int leadingBlanks;

  const KeyGrid({
    super.key,
    required this.grid,
    required this.keys,
    required this.keySize,
    this.onKeyPress,
    this.launching = const {},
    this.leadingBlanks = 0,
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
  /// A ceiling, so a tablet does not get keys the size of a hand. Nothing on a phone reaches it.
  static const maxKeySize = 140.0;

  static double sizeForDevice(Size screen, Grid grid) {
    const gapRatio = DeckTokens.keyGapRatioOfSide;
    final small = math.min(grid.rows, grid.cols);
    final big = math.max(grid.rows, grid.cols);
    double fit(double space, int n) => space / (n + (n - 1) * gapRatio);
    return math.max(
      24.0,
      math.min(
        fit(screen.shortestSide - _reserveShort, small),
        fit(screen.longestSide - _reserveLong, big),
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
  /// TWO reserves, one per edge, because the shell is not symmetric and a single number quietly
  /// picks the wrong constraint. Upright the long edge carries the top bar, the logo and the
  /// dots; sideways the long edge is the width, which carries only the side strip and the bezel
  /// sides. One reserve was fine while the SHORT edge happened to bind (3 rows sideways); at 2
  /// rows the long edge binds instead, and a single number then either shrinks the key by ~20% or
  /// lets the box cap bite in one orientation only — which is the rotation-resize this whole
  /// mechanism exists to prevent.
  ///
  /// RE-MEASURED after the bezel went to 4 at the sides and the deck went full screen sideways,
  /// against the same 393x873 logical phone:
  ///   upright   space 369x682  -> shell costs  24 wide, 191 tall
  ///   sideways  space 755x389  -> shell costs 118 wide,   4 tall
  /// The short edge of the DEVICE is the height sideways (4) and the width upright (24): worst
  /// case 24. The long edge is the width sideways (118) and the height upright (191): worst 191.
  ///
  /// The old 80 dated from a 20 px bezel and a status bar sideways; left alone it held the key at
  /// 95 in a box that now fits 112, which is the whole point of this pair of numbers being
  /// MEASURED rather than guessed.
  ///
  /// Measure with a deck that PAGINATES. 185 looked right against a single-page layout and then
  /// capped as soon as a second page appeared: the dots are 18 of those pixels, and they only
  /// exist when there is somewhere to go.
  static const _reserveShort = 24.0;
  static const _reserveLong = 191.0;

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
          // Cells the caller has taken for something else — the foreground-app panel, when it sits
          // on the first row. Blank rather than an empty KEY: an unlit cap under the panel is the
          // double frame this already had to be rid of once.
          for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
          for (final key in keys)
            KeyWidget(
              keyData: key,
              size: keySize,
              launching: launching.contains(key.pos),
              onPress: (p) => onKeyPress?.call(key.pos, p),
            ),
        ],
      ),
    );
  }
}
