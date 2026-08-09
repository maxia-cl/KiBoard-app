import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiboard_app/ui/nav.dart';

// The rule the whole file exists to keep: nothing over 250 ms. Flutter's own routes are 300 ms
// (Material) and 500 ms (Cupertino), so this fails the moment somebody drops the cap and inherits
// a default again.
void main() {
  const cap = Duration(milliseconds: 250);
  const nothing = SizedBox.shrink();

  test('no transition outlasts a quarter of a second, in either direction', () {
    final routes = <TransitionRoute>[
      screenRoute(nothing) as TransitionRoute,
      fadeRoute(nothing) as TransitionRoute,
    ];
    for (final route in routes) {
      expect(route.transitionDuration, lessThanOrEqualTo(cap));
      expect(route.reverseTransitionDuration, lessThanOrEqualTo(cap));
    }
  });

  test('a screen reached from the deck can be dragged back from the edge', () {
    // Cupertino's route is what provides that gesture, on Android too — it is the whole reason
    // these screens do not use a Material route, and the thing to notice if somebody swaps it back.
    expect(screenRoute(nothing), isA<CupertinoRouteTransitionMixin>());
  });
}
