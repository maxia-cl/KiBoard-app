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
class Splash extends StatefulWidget {
  const Splash({super.key});

  // Measured on the reference phone: Android's own splash screen holds the first ~1.2 s of a cold
  // start, and the hold only begins once Flutter draws. At 1200 ms the brand was on screen for
  // about half a second. This is the number that makes it readable — check it again on a fast
  // device before lowering it.
  static const _minimum = Duration(milliseconds: 1800);

  /// The mark fades in rather than appearing hard, but it starts on the FIRST frame. An earlier
  /// version waited 450 ms to stay out of Android's splash-exit animation — with the system splash
  /// now flat brand colour and no icon, that wait bought nothing and cost an empty coloured screen
  /// at every launch.
  static const _fade = Duration(milliseconds: 250);

  /// Runs [work] and the minimum display time together, so the splash costs nothing when the work
  /// is slower than it is.
  static Future<T> hold<T>(Future<T> work) async {
    final results = await Future.wait([work, Future<void>.delayed(_minimum)]);
    return results.first as T;
  }

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    // Next frame, so the opacity actually animates from 0 instead of building at 1.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = Brand.of(context);
    final logo = Brand.logoAsset(context);

    // Sized off the SHORT side, so the phone held sideways at launch scales the mark down instead
    // of blowing it across the screen. Fixed pixel sizes looked right in one orientation only.
    //
    // No watermark: KiMouse can put its mark behind itself because that mark is a transparent
    // silhouette. KiBoard's is a solid tile, and at any opacity it reads as a card sitting behind
    // the logo rather than as texture on the paper.
    final short = MediaQuery.sizeOf(context).shortestSide;

    return Scaffold(
      backgroundColor: brand.paper,
      body: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: Splash._fade,
        curve: Curves.easeOut,
        // Centred explicitly. The first version leaned on a Stack, which takes the size of its
        // biggest child under loose constraints — so the composition sat at the top of the screen
        // instead of the middle. That, plus the watermark reading as a card, is what looked like
        // the start screen appearing "in a corner".
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(logo, width: short * 0.6, semanticLabel: 'KiBoard'),
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
        ),
      ),
    );
  }
}
