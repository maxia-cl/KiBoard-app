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

  static const _minimum = Duration(milliseconds: 1200);

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

    return Scaffold(
      backgroundColor: brand.paper,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // The watermark is the same file, blown up and almost invisible. At 6% it reads as
          // texture on the paper rather than as a second logo.
          Opacity(
            opacity: 0.06,
            child: Image.asset(logo, width: 460, excludeFromSemantics: true),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(logo, width: 200, semanticLabel: 'KiBoard'),
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
