import 'package:flutter_test/flutter_test.dart';

import 'package:kiboard_app/main.dart';

void main() {
  testWidgets('App boots to the discovery screen', (WidgetTester tester) async {
    await tester.pumpWidget(const KiBoardApp());
    expect(find.text('KiBoard'), findsOneWidget);
    expect(find.textContaining('Looking for PCs'), findsOneWidget);

    // MockDiscovery.discover() resolves after ~900ms; let that timer finish before the test ends.
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
