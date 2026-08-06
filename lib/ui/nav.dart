import 'package:flutter/cupertino.dart';

/// How the app moves between screens.
///
/// Two rules, and they are the whole design: **nothing lasts longer than 250 ms**, and **no
/// animation may delay a press**. This is a key pad — a deck key hit from muscle memory has to
/// answer now, and a transition that plays for 400 ms while the phone waits is a transition that
/// makes the hardware feel slower than it is. Flutter's own routes are 300 ms (Material) and
/// 500 ms (Cupertino), so both are capped here rather than accepted.
const _fast = Duration(milliseconds: 220);

/// A screen reached FROM the deck: the trackpad, dictation, the window switcher, the manual.
///
/// Cupertino on purpose, on Android too: what it buys is the interactive **edge-drag back**, which
/// Material's route does not have. Coming back from the trackpad with a thumb already at the edge
/// of the screen beats reaching for a button, and it costs no gesture code of our own.
///
/// ponytail: the plan asked for a container transform out of the pressed key. That needs the
/// `animations` package and the KEY widget to own the navigation — but `_handlePress` has to run
/// the §3 danger confirmation and the §4.2.1 client-action branch before anything opens, so the
/// key cannot be the thing that decides. Left as a plain transition until that is worth untangling.
Route<T> screenRoute<T>(Widget child) => _FastCupertinoRoute<T>(builder: (_) => child);

/// A swap where nothing carries over: pairing → the deck, the deck → pairing again.
///
/// A push would slide a screen in from the right as if it were deeper in a stack, and it is not —
/// it replaces everything. A fade-through says "different place" without implying a way back.
Route<T> fadeRoute<T>(Widget child) => PageRouteBuilder<T>(
  pageBuilder: (_, _, _) => child,
  transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
  transitionDuration: _fast,
  reverseTransitionDuration: _fast,
);

class _FastCupertinoRoute<T> extends CupertinoPageRoute<T> {
  _FastCupertinoRoute({required super.builder});

  @override
  Duration get transitionDuration => _fast;

  @override
  Duration get reverseTransitionDuration => _fast;
}
