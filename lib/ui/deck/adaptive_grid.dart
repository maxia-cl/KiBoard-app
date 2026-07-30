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
  /// Briefly 3 along the short edge, once moving the chrome off that axis made a third row fit.
  /// It fits, but the keys pay for it — 15 keys of 96.9 logical pixels against 10 of 124. The
  /// reclaimed space went into key SIZE instead: a Stream Deck is hit from muscle memory and a
  /// bigger target is worth more than a denser grid. Two more pages are one swipe away; a key too
  /// small to hit without looking is a key you stop using.
  static const _long = 5;
  static const _short = 2;

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
