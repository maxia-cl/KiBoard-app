import 'package:flutter_test/flutter_test.dart';

import 'package:kiboard_app/main.dart';

void main() {
  testWidgets('App boots to the discovery screen', (WidgetTester tester) async {
    await tester.pumpWidget(const KiBoardApp());
    expect(find.text('KiBoard'), findsOneWidget);
    expect(find.textContaining('Looking for PCs'), findsOneWidget);

    // Real mDNS discovery has no platform channel in a test sandbox and never resolves here —
    // don't pumpAndSettle (the spinner it leaves showing animates forever and times that out).
    await tester.pump();
  });
}
