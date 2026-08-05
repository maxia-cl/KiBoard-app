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
  /// **12 keys, shaped to the orientation: 3x4 upright, 6x2 sideways.**
  ///
  /// Not a transpose any more, and that is the point. Upright the key is bound by width and
  /// sideways by HEIGHT — measured on the reference phone, 369x655 against 755x320 — so a shape
  /// that merely swaps rows and columns cannot give the same key twice. 3x5 upright reads 112.5;
  /// its transpose sideways reads 97.6, because three rows have to fit in 320.
  ///
  /// 3x4 / 6x2 does: 112.5 and 112.7. Same key, same twelve keys on the page, rearranged rather
  /// than repaginated — the host paginates by COUNT, so what travels is the same twelve either
  /// way. It costs one row upright against the 3x5 that came before it.
  static const _count = 12;
  static const _upright = Grid(rows: 4, cols: 3);
  static const _sideways = Grid(rows: 2, cols: 6);

  /// Keys per page, whatever the orientation.
  static const count = _count;

  /// Keys along the short edge of the device.
  static const short = 3;

  /// Keys along the long edge.
  static const long = 4;

  static Grid forSpace(double width, double height) => width >= height ? _sideways : _upright;
}
