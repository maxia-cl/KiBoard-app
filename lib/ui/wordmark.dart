import 'package:flutter/material.dart';

import 'brand.dart';

/// The product name: the brush mark, tinted, plus the rest of the word in a light sans with wide
/// tracking. KiMouse's lockup, in KiBoard's colours — same construction is what makes two apps read
/// as one house, and it appears in exactly the same two places there: the start screen, stacked,
/// and the top of the app, in a row.
///
/// One widget for both so the tint and the tracking cannot drift apart. [markHeight] is the only
/// thing a caller picks; the word follows it.
class Wordmark extends StatelessWidget {
  final double markHeight;
  final bool stacked;

  const Wordmark({super.key, required this.markHeight, this.stacked = false});

  /// KiMouse's ratios: a 34 dp brush over 22 sp of text in the header, 185 over 40 on the splash.
  double get _fontSize => stacked ? markHeight * 0.28 : markHeight * 0.65;

  @override
  Widget build(BuildContext context) {
    final brand = Brand.of(context);
    final mark = Image.asset(
      'assets/brand/mark.png',
      height: markHeight,
      color: brand.accent,
      colorBlendMode: BlendMode.srcIn,
      semanticLabel: 'KiBoard',
    );
    final word = Text(
      'board',
      style: TextStyle(
        color: brand.ink,
        fontSize: _fontSize,
        fontWeight: FontWeight.w300,
        letterSpacing: _fontSize * 0.28, // the tracking KiMouse sets on "mouse"
      ),
    );

    return stacked
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              mark,
              SizedBox(height: markHeight * 0.04),
              word,
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              mark,
              SizedBox(width: markHeight * 0.18),
              word,
            ],
          );
  }
}
