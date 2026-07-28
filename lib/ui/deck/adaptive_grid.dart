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
  /// 6 keys along the long edge, 2 along the short one. Twelve keys is roughly Elgato's mk2 (15)
  /// and comfortably tappable on a phone at either orientation.
  static const _long = 6;
  static const _short = 2;

  /// [width] and [height] are the space left for the grid itself — the caller has already taken
  /// out the top bar and everything the bezel puts around it.
  static Grid forSpace(double width, double height) => width >= height
      ? const Grid(rows: _short, cols: _long)
      : const Grid(rows: _long, cols: _short);
}
