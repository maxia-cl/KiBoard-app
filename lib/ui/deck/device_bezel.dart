import 'package:flutter/material.dart';

import '../tokens.g.dart';

/// The physical shell (§3.0): matte dark bezel, wider bottom padding, engraved logo. Governs both
/// the deck screen and the window switcher (§3.5) — same bezel, same key, same pagination.
class DeviceBezel extends StatelessWidget {
  final double gridWidth;
  final double gridHeight;
  final Widget child;
  final int pageCount;
  final int currentPage;

  /// Sideways the dots move into the side strip, where the spare axis is. Height is what limits
  /// the keys when the phone is held that way, and an indicator is not worth a row of pixels off
  /// every key.
  final bool dotsInside;

  const DeviceBezel({
    super.key,
    required this.gridWidth,
    required this.gridHeight,
    required this.child,
    this.pageCount = 1,
    this.currentPage = 0,
    this.dotsInside = true,
  });

  /// The logo's line box, PINNED rather than estimated: the style below sets `height: 1.2`, so
  /// this is 11 x 1.2 and not whatever line height the ambient theme happens to carry. It was
  /// "16, rounded up" and the real box was 20 — invisible while the key had slack to absorb it,
  /// a 4 px overflow the moment the grid started taking the whole box.
  static const _logoLineHeight = 11 * 1.2;

  /// Below this height the shell goes compact. A phone held sideways has ~390 logical pixels top
  /// to bottom, and the full-size padding plus the engraved logo were eating a third of it — on
  /// the axis that decides how big the keys can be. The logo is device jewellery; the keys are the
  /// product, so on a short screen the jewellery goes.
  static const _compactBelow = 450.0;

  static bool isCompact(double availableHeight) => availableHeight < _compactBelow;

  // Compact is the phone held sideways, where every pixel of height is a pixel off the keys.
  // Trimmed to the minimum that still reads as a bezel rather than a hairline.
  /// 2, not 6, on a short screen: sideways those 8 pixels are the difference between a key that
  /// matches the upright one and one that does not, and at this size the frame still reads.
  static double _padTop(bool compact) => compact ? 2 : DeckTokens.bezelPaddingTopPx;
  static double _padBottom(bool compact) => compact ? 2 : DeckTokens.bezelPaddingBottomPx;

  /// Vertical space the bezel needs BEYOND the grid it wraps: its padding, the page dots when
  /// there is more than one page, and the engraved logo.
  ///
  /// Callers size the grid to the space that is left, so this has to live here — a caller
  /// guessing it is how the deck came to overflow by exactly the height of the logo in landscape.
  static double chromeHeightFor(int pageCount, double availableHeight, {bool dotsInside = true}) {
    final compact = isCompact(availableHeight);
    return _padTop(compact) +
        _padBottom(compact) +
        (dotsInside && pageCount > 1 ? 18 : 0) + // 10 gap + 8 dot
        (compact ? 0 : 8 + _logoLineHeight);
  }

  /// One page dot, so the bezel and the side strip cannot drift apart on how a dot looks.
  ///
  /// The margin goes on the axis the dots are laid out along, never both: in the bezel they sit in
  /// a Row whose height `chromeHeightFor` has already budgeted at 8, so a vertical margin here is
  /// height nobody reserved — which is precisely how this overflowed the deck by 4.4 pixels.
  static Widget dot(bool active, {bool stacked = false}) => Container(
    margin: stacked
        ? const EdgeInsets.symmetric(vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 3),
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active
          ? const Color(DeckTokens.pageDotActive)
          : const Color(DeckTokens.pageDotInactive),
    ),
  );

  /// Horizontal space the bezel needs beyond the grid.
  /// The drawn frame down each side. Thin on purpose: upright the key is bound by height, so
  /// every pixel here is margin taken off the grid's width and given to nothing — at 20 it was the
  /// difference between two columns and three. The top and bottom keep the token's full padding,
  /// which is where the bezel still reads as a bezel.
  static const _padSide = 4.0;

  static double chromeWidth() => 2 * _padSide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = isCompact(constraints.maxHeight);
        return _shell(compact);
      },
    );
  }

  Widget _shell(bool compact) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(DeckTokens.bezelGradientFrom), Color(DeckTokens.bezelGradientTo)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(DeckTokens.bezelCornerRadiusPx),
      ),
      padding: EdgeInsets.fromLTRB(_padSide, _padTop(compact), _padSide, _padBottom(compact)),
      // Fills whatever it is given and centres the keys inside, rather than shrink-wrapping them.
      // Shrink-wrapped, the pad floated as a small slab in the middle of the screen; the phone is
      // meant to BE the device (§3.0), so the shell goes edge to edge and the keys sit in it.
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The grid takes what is left after the fixed parts below, instead of a height the
          // caller worked out for it. Two places computing the same number is how a 4 px
          // overflow appears the moment one of them is off — and `chromeHeightFor` had to guess
          // at a text line box, which is a number only the text engine really knows.
          Flexible(
            child: SizedBox(width: gridWidth, height: gridHeight, child: child),
          ),
          if (dotsInside && pageCount > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (var i = 0; i < pageCount; i++) dot(i == currentPage)],
            ),
          ],
          // Dropped on a short screen: see [_compactBelow]. Every pixel it takes is a pixel off
          // the keys, on the axis that limits them.
          if (!compact) ...[
            const SizedBox(height: 8),
            const Text(
              DeckTokens.bezelLogoText,
              style: TextStyle(
                color: Color(DeckTokens.textSecondary),
                fontSize: 11,
                height: 1.2,
                letterSpacing: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
