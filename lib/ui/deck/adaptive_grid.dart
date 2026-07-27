import 'dart:math' as math;

import '../../model/deck.dart';
import '../tokens.g.dart';

/// Chooses `rows × cols` for the space the key pad actually has
/// (docs/implementation-plan.md §3.1: "the phone computes rows × cols from screen size **and
/// orientation** and declares it in `hello`").
///
/// A fixed 3×5 was the mock-up's shape, not a rule. Held sideways — the natural way to hold a key
/// pad — a 3×5 grid leaves most of the screen empty, because the number of columns, not the key
/// size, is what limits it. Deriving the grid instead means the keys stay a comfortable size and
/// the device fills the screen in both orientations.
class AdaptiveGrid {
  /// The key size to aim for, in logical pixels — comfortably above `key.sizePx` (72), the
  /// reference the visual language is drawn at. The grid takes as many keys of about this size as
  /// fit; `KeyGrid.sizeToFit` then grows them to take up the remainder exactly.
  static const _targetKey = 84.0;

  /// Never fewer keys than "mini" (2×3) — below that it stops being a key pad.
  static const _minCols = 3;
  static const _minRows = 2;

  /// Width caps at "xl" (8 columns): past that the keys shrink, because width is what limits them
  /// on every phone. Height goes further than xl's 4 rows on purpose — `gridPresets.auto` is
  /// `basedOn: screenSize`, not a hardware shape, and a phone stood upright is far taller than any
  /// real deck. Up to 6 rows the WIDTH is still the binding constraint, so those extra rows cost
  /// nothing in key size and simply stop the device floating in a sea of black.
  static const _maxCols = 8;
  static const _maxRows = 6;

  /// [width] and [height] are the space left for the grid itself — the caller has already taken
  /// out the top bar and everything the bezel puts around it.
  static Grid forSpace(double width, double height) {
    const gap = 1 + DeckTokens.keyGapRatioOfSide;
    int fit(double space, int lo, int hi) =>
        math.max(0, space ~/ (_targetKey * gap)).clamp(lo, hi);

    return Grid(rows: fit(height, _minRows, _maxRows), cols: fit(width, _minCols, _maxCols));
  }
}
