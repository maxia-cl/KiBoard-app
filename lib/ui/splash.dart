import 'package:flutter/material.dart';

import 'brand.dart';

/// The first thing the app shows, in KiBoard's own colours rather than the deck's.
///
/// The shape is KiMouse's: the mark once, very large and very faint, behind the mark again at
/// reading size, with the product name under it in a light, widely spaced sans. Same family,
/// different colours — that is what makes two apps look like they came from the same place.
///
/// It is not a loading spinner. It stays up for [_minimum] even when the deck is ready sooner,
/// because a brand mark that flashes for 80 ms reads as a glitch. Anything slower than that — a
/// reconnect to a sleeping host — hides behind it for free.
class Splash extends StatelessWidget {
  const Splash({super.key});

  // Measured on the reference phone: Android's own splash screen holds the first ~1.2 s of a cold
  // start, and the hold only begins once Flutter draws. At 1200 ms the brand was on screen for
  // about half a second. This is the number that makes it readable — check it again on a fast
  // device before lowering it.
  static const _minimum = Duration(milliseconds: 1800);

  /// Runs [work] and the minimum display time together, so the splash costs nothing when the work
  /// is slower than it is.
  static Future<T> hold<T>(Future<T> work) async {
    final results = await Future.wait([work, Future<void>.delayed(_minimum)]);
    return results.first as T;
  }

  @override
  Widget build(BuildContext context) {
    final brand = Brand.of(context);
    final logo = Brand.logoAsset(context);

    // Sized off the SHORT side, so the phone being held sideways at launch scales the mark down
    // instead of blowing it across the screen. Fixed pixel sizes looked right in one orientation
    // and only in that one.
    final short = MediaQuery.sizeOf(context).shortestSide;

    return Scaffold(
      backgroundColor: brand.paper,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // The watermark is the square mark, NOT the full logo: two copies of the same wordmark
          // at different sizes collide, and the tiles of the big one land on the name. KiMouse
          // gets away with one file because its mark is a single silhouette.
          Opacity(
            opacity: 0.05,
            child: Image.asset(
              'assets/brand/icon.png',
              width: short * 0.85,
              excludeFromSemantics: true,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(logo, width: short * 0.55, semanticLabel: 'KiBoard'),
              const SizedBox(height: 10),
              Text(
                'KiBoard',
                style: TextStyle(
                  color: brand.ink,
                  fontSize: 34,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
