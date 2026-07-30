import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kiboard_app/main.dart';
import 'package:kiboard_app/net/discovered_host.dart';
import 'package:kiboard_app/net/saved_session.dart';
import 'package:kiboard_app/model/deck.dart';
import 'package:kiboard_app/ui/deck/adaptive_grid.dart';
import 'package:kiboard_app/ui/deck/key_grid.dart';

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

  // §3.1: the phone derives its grid from the screen. The count is fixed and only the orientation
  // changes — a deck the user arranged must hold the same keys whichever way the phone is held,
  // or rotating silently repaginates a surface whose whole value is muscle memory.
  group('AdaptiveGrid', () {
    test('rotating transposes the grid and keeps the key count', () {
      // Logical pixels for a 1080x2400 phone at ~2.75x, minus the top bar and bezel.
      final portrait = AdaptiveGrid.forSpace(320, 700);
      final landscape = AdaptiveGrid.forSpace(780, 240);

      expect(landscape.cols, portrait.rows);
      expect(landscape.rows, portrait.cols);
      expect(landscape.cols * landscape.rows, portrait.cols * portrait.rows);
      expect(landscape.cols, greaterThan(landscape.rows)); // long edge gets the columns
    });

    // The requirement that drives `sizeForDevice`: a key pad is hit from muscle memory, so a
    // target that resizes when the phone turns is a different target. Sizing from the space
    // available cannot deliver this — the system bars land on the height in BOTH orientations, so
    // the usable box is not a transpose of itself.
    test('key size is identical in both orientations', () {
      const screen = Size(393, 873); // logical size of the test phone, upright
      const rotated = Size(873, 393);

      final upright = KeyGrid.sizeForDevice(
        screen,
        const Grid(rows: AdaptiveGrid.long, cols: AdaptiveGrid.short),
      );
      final sideways = KeyGrid.sizeForDevice(
        rotated,
        const Grid(rows: AdaptiveGrid.short, cols: AdaptiveGrid.long),
      );

      expect(sideways, upright);
    });

    test('the key count never changes with screen size', () {
      const sizes = [Size(1, 1), Size(400, 800), Size(4000, 4000), Size(800, 400)];
      final counts = sizes
          .map((s) => AdaptiveGrid.forSpace(s.width, s.height))
          .map((g) => g.cols * g.rows)
          .toSet();
      expect(counts, hasLength(1), reason: 'a tablet and a phone must show the same deck');
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

  // R1: the typed address is the path that works on a network which never passes mDNS on, so it
  // has to accept what a person actually types — including the whole URL, if that is what the PC
  // showed them — and refuse what it cannot read instead of dialling a guess.
  group('parseHostAddress', () {
    test('a bare address takes the default port', () {
      expect(parseHostAddress('192.168.1.11'), (host: '192.168.1.11', port: defaultHostPort));
      expect(parseHostAddress('  desktop.local  '), (host: 'desktop.local', port: defaultHostPort));
    });

    test('an explicit port wins', () {
      expect(parseHostAddress('192.168.1.11:9000'), (host: '192.168.1.11', port: 9000));
    });

    test('a pasted URL is read, not rejected', () {
      expect(parseHostAddress('ws://192.168.1.11:8770'), (host: '192.168.1.11', port: 8770));
      expect(parseHostAddress('http://desktop.local/'), (host: 'desktop.local', port: defaultHostPort));
    });

    test('IPv6 keeps its colons', () {
      // Bracketed, with and without a port.
      expect(parseHostAddress('[::1]:9000'), (host: '::1', port: 9000));
      expect(parseHostAddress('[fe80::1]'), (host: 'fe80::1', port: defaultHostPort));
      // Bare: every colon belongs to the address. Reading the last group as a port would dial
      // somewhere else entirely — the same trap `wsUri` exists for.
      expect(
        parseHostAddress('2803:c600:5108:844a:80a9:4d6f:5152:153b'),
        (host: '2803:c600:5108:844a:80a9:4d6f:5152:153b', port: defaultHostPort),
      );
    });

    test('what it cannot read comes back null', () {
      const bads = [
        '', '   ', ':8770', '192.168.1.11:', '192.168.1.11:abc',
        '192.168.1.11:0', '192.168.1.11:70000', '[::1', '[]', 'ws://',
        'my pc', // a host cannot contain a space
        // Colon-heavy but not an address. Taking these on faith handed `wsUri` a FormatException
        // instead of telling the user about their typo.
        'not an address:::', 'a:b:c', '[nope]:8770',
      ];
      for (final bad in bads) {
        expect(parseHostAddress(bad), isNull, reason: 'should refuse "$bad"');
      }
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
