// Exercises the FP demo script end to end (docs/implementation-plan.md §5, FP deliverable 5):
// discover a PC -> pair -> key pad in auto -> switch to manual -> folder -> window switcher.
// Screenshots aren't available in every environment this runs in, so this test drives the same
// widget tree flutter_test does for any Flutter app: real taps and real gesture disambiguation,
// no visual rendering required.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiboard_app/main.dart';

void main() {
  testWidgets('discover -> pair -> auto deck -> manual deck -> folder -> window switcher', (
    WidgetTester tester,
  ) async {
    // KeyWidget registers onTap alongside onDoubleTap/onLongPress, so Flutter's gesture arena
    // holds a plain tap pending until the double-tap timeout elapses before resolving it as
    // "short". Every tap on a deck key needs this extra settle time; plain buttons don't.
    Future<void> tapKey(Finder finder) async {
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(const KiBoardApp());
    await tester.pumpAndSettle(const Duration(seconds: 1)); // MockDiscovery.discover() delay

    expect(find.text("M3X's PC"), findsOneWidget);
    await tester.tap(find.text("M3X's PC"));
    await tester.pumpAndSettle();

    expect(find.text('"M3X\'s PC" wants to connect'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '418203');
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle(const Duration(seconds: 1)); // MockDiscovery.confirmCode() delay

    // Auto mode: the Photoshop profile fixture should be showing.
    expect(find.text('Adobe Photoshop'), findsOneWidget);
    expect(find.text('Brush'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Switch to manual mode.
    await tester.tap(find.text('Auto').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual').last);
    await tester.pumpAndSettle();

    expect(find.text('Photoshop'), findsOneWidget);
    expect(find.text('Excel'), findsOneWidget);
    expect(find.text('OBS'), findsOneWidget);

    // Enter the OBS folder.
    await tapKey(find.text('OBS'));
    expect(find.text('Start streaming'), findsOneWidget);
    expect(find.text('Scene: Game'), findsOneWidget);

    // Back out via the folder's auto-added back key.
    await tapKey(find.text('Back'));
    expect(find.text('Photoshop'), findsOneWidget);

    // Open the window switcher.
    await tapKey(find.text('Windows'));
    expect(find.text('Open windows'), findsOneWidget);
    expect(find.text('Photoshop'), findsWidgets); // MRU position 0, flagged current
    expect(find.text('Google Chrome'), findsOneWidget);

    // Focus a window closes the switcher and returns to the deck.
    await tapKey(find.text('Google Chrome'));
    expect(find.text('Open windows'), findsNothing);
  });
}
