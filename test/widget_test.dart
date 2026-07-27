import 'package:flutter_test/flutter_test.dart';

import 'package:kiboard_app/main.dart';
import 'package:kiboard_app/net/discovered_host.dart';

void main() {
  // Regression: mDNS answers with an IPv6 address often enough that this decides whether pairing
  // works at all. `'ws://$ip:$port'` throws `FormatException: Invalid port` on a bare IPv6 literal
  // — the first colon of the address reads as the port separator.
  group('wsUri', () {
    test('brackets IPv6 literals', () {
      expect(
        wsUri('2803:c600:5108:844a:80a9:4d6f:5152:153b', 8770).toString(),
        'ws://[2803:c600:5108:844a:80a9:4d6f:5152:153b]:8770',
      );
    });

    test('leaves IPv4 and hostnames alone', () {
      expect(wsUri('192.168.1.11', 8770).toString(), 'ws://192.168.1.11:8770');
      expect(wsUri('desktop.local', 8770).toString(), 'ws://desktop.local:8770');
    });
  });

  testWidgets('App boots to the discovery screen', (WidgetTester tester) async {
    await tester.pumpWidget(const KiBoardApp());
    expect(find.text('KiBoard'), findsOneWidget);
    expect(find.textContaining('Looking for PCs'), findsOneWidget);

    // Real mDNS discovery has no platform channel in a test sandbox — don't pumpAndSettle, the
    // spinner animates forever. Discovery is BOUNDED now, though, so advancing past its window
    // makes it give up, which both drains the pending timer and proves the screen can no longer
    // strand the user on a spinner (the bug seen on the phone after an app restart).
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('No PCs found'), findsOneWidget);
  });
}
