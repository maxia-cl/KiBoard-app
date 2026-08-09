import '../../model/deck.dart';

/// The key pad's shape, oriented to the screen (docs/implementation-plan.md §3.1: the phone
/// derives its grid and declares it in `hello`).
///
/// Deliberately a FIXED number of keys, transposed rather than recomputed: a deck the user has
/// arranged should hold the same keys whichever way the phone is held, so rotating rotates the
/// device — it does not reshuffle it onto a different number of pages. Sizing the grid to the
/// screen instead made the key count jump between orientations, which is disorienting on a surface
/// whose whole value is muscle memory.
class AdaptiveGrid {
  /// 5 keys along the long edge, 2 along the short one. What does not fit goes to the next page
  /// (§3.1), it is not lost.
  ///
  /// 3 on the short edge, decided by measuring rather than by argument. It was 2 because a third
  /// column looked like it cost 10% of the key — but that measurement kept the bezel's 20 px of
  /// side padding, and upright the key is bound by HEIGHT, so those 20 px were pure margin next to
  /// 54 more of centring slack. With the bezel at 4 the third column costs 1.4%: 112.5 against
  /// 114.1, which is inside the noise. What it really costs is the width of the drawn frame.
  static const _long = 5;
  static const _short = 3;

  /// Keys per page, whatever the orientation.
  static const count = _long * _short;

  /// Keys along the short edge of the device — the count that decides key size, since the short
  /// edge is what binds.
  static const short = _short;

  /// Keys along the long edge.
  static const long = _long;

  /// [width] and [height] are the space left for the grid itself — the caller has already taken
  /// out the top bar and everything the bezel puts around it.
  static Grid forSpace(double width, double height) => width >= height
      ? const Grid(rows: _short, cols: _long)
      : const Grid(rows: _long, cols: _short);
}
