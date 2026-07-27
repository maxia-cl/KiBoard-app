import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kiboard_app/main.dart';
import 'package:kiboard_app/net/discovered_host.dart';
import 'package:kiboard_app/net/saved_session.dart';

void main() {
  // A stored session is what lets the app skip pairing on every launch, so its round trip is worth
  // pinning: a corrupt entry in particular must send the user to pairing, never crash the launch.
  group('SavedSession', () {
    test('round-trips through storage', () async {
      SharedPreferences.setMockInitialValues({});
      const saved = SavedSession(
        ip: '192.168.1.11',
        port: 8770,
        token: 'deadbeef',
        deviceId: 'abc123',
        hostName: 'KiBoard Host',
      );
      await saved.save();

      final loaded = await SavedSession.load();
      expect(loaded, isNotNull);
      expect(loaded!.ip, '192.168.1.11');
      expect(loaded.token, 'deadbeef');
      expect(loaded.hostName, 'KiBoard Host');
    });

    test('a corrupt entry reads as "not paired" instead of throwing', () async {
      SharedPreferences.setMockInitialValues({'session': 'not json at all'});
      expect(await SavedSession.load(), isNull);
      // ...and clears itself, so the launch after this one is not slowed by the same garbage.
      SharedPreferences.setMockInitialValues({'session': 'not json at all'});
      await SavedSession.load();
      expect(await SavedSession.load(), isNull);
    });

    test('clear removes it', () async {
      SharedPreferences.setMockInitialValues({});
      await const SavedSession(ip: 'a', port: 1, token: 't', deviceId: 'd', hostName: 'h').save();
      expect(await SavedSession.load(), isNotNull);
      await SavedSession.clear();
      expect(await SavedSession.load(), isNull);
    });
  });

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

  testWidgets('with no saved session, the app boots to discovery', (WidgetTester tester) async {
    // No stored session: a phone that has never paired must land on discovery, not on a deck it
    // has no host for.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const KiBoardApp());
    await tester.pump(); // BootScreen resolves SavedSession.load()
    await tester.pump();
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
