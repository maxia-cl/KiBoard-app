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
  /// 5 keys along the long edge, 3 along the short one. What does not fit goes to the next page
  /// (§3.1), it is not lost.
  ///
  /// Was 2 along the short edge until the chrome moved off that axis in landscape: the top bar
  /// used to eat the very dimension that decides how many rows fit, so a third row did not pay for
  /// itself. With the bar on the side there is room, and 15 keys beat 10 — at the price of a key
  /// about a fifth smaller, which is the trade the extra row costs.
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
