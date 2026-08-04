import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kiboard_app/main.dart';
import 'package:kiboard_app/net/discovered_host.dart';
import 'package:kiboard_app/net/layout_source.dart';
import 'package:kiboard_app/net/saved_session.dart';
import 'package:kiboard_app/ui/splash.dart';
import 'package:kiboard_app/ui/wordmark.dart';
import 'package:kiboard_app/model/deck.dart';
import 'package:kiboard_app/ui/deck/adaptive_grid.dart';
import 'package:kiboard_app/ui/deck/deck_screen.dart';
import 'package:kiboard_app/ui/deck/key_grid.dart';
import 'package:kiboard_app/ui/deck/key_widget.dart';

/// Ten keys on the phone's own grid — what a real host sends once it has repaginated for the grid
/// the client declared in `hello`. DeckScreen reshapes it to the orientation itself as long as the
/// capacity matches, which is the case this exists to produce.
class _TenKeys implements LayoutSource {
  final _controller = StreamController<Layout>.broadcast();

  /// Makes key 0 a `danger` key, so the confirmation can be driven.
  final bool danger;

  /// Positions that actually reached the host.
  final pressed = <int>[];

  _TenKeys({this.danger = false});

  Layout get _layout => Layout(
    mode: 'auto',
    source: const LayoutSourceInfo(kind: 'profile', id: 'test', appName: 'Test'),
    grid: const Grid(rows: 5, cols: 2),
    page: 0,
    pages: 1,
    keys: [
      DeckKey(
        pos: 0,
        label: danger ? 'Close app' : 'Copy',
        action: 'ctrl+c',
        danger: danger,
        kind: KeyKind.action,
      ),
      ...List.generate(9, (i) => DeckKey.empty(i + 1)),
    ],
  );

  @override
  Stream<Layout> layouts() {
    scheduleMicrotask(() => _controller.add(_layout));
    return _controller.stream;
  }

  @override
  Future<void> pressKey({required int pos, required String press}) async {
    pressed.add(pos);
  }
  @override
  Future<void> setMode(String mode, {String? deckId}) async {}
  @override
  Future<WindowsPage> listWindows(int page) async => throw UnimplementedError();
  @override
  Future<void> focusWindow(int windowId) async {}

  void dispose() => _controller.close();
}

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
  group('wssUri', () {
    test('brackets IPv6 literals', () {
      expect(
        wssUri('2803:c600:5108:844a:80a9:4d6f:5152:153b', 8770).toString(),
        'wss://[2803:c600:5108:844a:80a9:4d6f:5152:153b]:8770',
      );
    });

    test('leaves IPv4 and hostnames alone', () {
      expect(wssUri('192.168.1.11', 8770).toString(), 'wss://192.168.1.11:8770');
      expect(wssUri('desktop.local', 8770).toString(), 'wss://desktop.local:8770');
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

  /// The unit test above pins `sizeForDevice`, which is orientation-independent by construction —
  /// so it cannot fail. What CAN fail is the other half: `sizeToFit` capping that size when the
  /// shell turns out wider than the reserve assumed, in one orientation only. That is the runtime
  /// `CAPPED BY BOX` case, and it is what widening the landscape strip risks.
  ///
  /// So this one measures the key as actually laid out, both ways up.
  testWidgets('the rendered key is the same size held either way', (tester) async {
    // A layout of the shape a REAL host sends: ten keys on the phone's own grid, which transposes
    // to 5x2 upright and 2x5 sideways. The FP fixtures are 3x5 = fifteen, so the capacity guard in
    // DeckScreen keeps their grid rather than the phone's and renders five columns into a portrait
    // box — which caps by width and would make this measure the wrong thing entirely.
    final source = _TenKeys();
    addTearDown(source.dispose);

    Future<double> keySizeAt(Size screen) async {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: screen),
          child: MaterialApp(
            home: DeckScreen(layoutSource: source, hostName: "M3X's PC"),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // the fixture arrives on the stream
      return tester.getSize(find.byType(KeyWidget).first).width;
    }

    // The reference phone, upright and sideways.
    final upright = await keySizeAt(const Size(393, 873));
    final sideways = await keySizeAt(const Size(873, 393));

    expect(sideways, moreOrLessEquals(upright, epsilon: 0.5),
        reason: 'the side strip is eating enough width to shrink the keys — check _verticalWidth '
            'against the slack described on KeyGrid._reserveLong');
  });

  /// §3 says a `danger` key is painted red AND asks before it acts. Only the paint was built, so
  /// "Cerrar app" closed whatever was in front on one mis-tap — on a surface hit from muscle
  /// memory, sitting next to keys that do nothing worse than copy.
  group('a danger key asks first', () {
    Future<_TenKeys> pumpDeck(WidgetTester tester) async {
      final source = _TenKeys(danger: true);
      addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(home: DeckScreen(layoutSource: source, hostName: 'PC')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return source;
    }

    testWidgets('and does nothing when the answer is no', (tester) async {
      final source = await pumpDeck(tester);
      await tester.tap(find.byType(KeyWidget).first);
      // A key registers `onDoubleTap`, so the recognizer holds the short press back until the
      // double-tap window closes. `pumpAndSettle` does not advance that timer — it only pumps
      // frames — so the tap would otherwise never land.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Close app?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(source.pressed, isEmpty, reason: 'cancelling must not reach the host');
    });

    testWidgets('and goes through when the answer is yes', (tester) async {
      final source = await pumpDeck(tester);
      await tester.tap(find.byType(KeyWidget).first);
      // A key registers `onDoubleTap`, so the recognizer holds the short press back until the
      // double-tap window closes. `pumpAndSettle` does not advance that timer — it only pumps
      // frames — so the tap would otherwise never land.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Close app'));
      await tester.pumpAndSettle();
      expect(source.pressed, [0]);
    });

    testWidgets('while an ordinary key still goes straight through', (tester) async {
      final source = _TenKeys();
      addTearDown(source.dispose);
      await tester.pumpWidget(MaterialApp(home: DeckScreen(layoutSource: source, hostName: 'PC')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(KeyWidget).first);
      // A key registers `onDoubleTap`, so the recognizer holds the short press back until the
      // double-tap window closes. `pumpAndSettle` does not advance that timer — it only pumps
      // frames — so the tap would otherwise never land.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(source.pressed, [0]);
    });
  });

  testWidgets('with no saved session, the app boots to discovery', (WidgetTester tester) async {
    // No stored session: a phone that has never paired must land on discovery, not on a deck it
    // has no host for.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const KiBoardApp());
    await tester.pump(); // BootScreen resolves SavedSession.load()
    await tester.pump();

    // The brand mark comes first and holds, so it cannot flash past as a glitch. Discovery is
    // behind it — asserting the order here is what stops the hold from being quietly dropped.
    expect(find.byType(Splash), findsOneWidget);
    expect(find.textContaining('Looking for PCs'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1900));

    expect(find.byType(Splash), findsNothing);
    // The name is the lockup now — a tinted mark plus the rest of the word — in both places, so
    // there is no plain 'KiBoard' string to look for.
    expect(find.byType(Wordmark), findsOneWidget);
    expect(find.textContaining('Looking for PCs'), findsOneWidget);

    // Real mDNS discovery has no platform channel in a test sandbox — don't pumpAndSettle, the
    // spinner animates forever. Discovery is BOUNDED now, though, so advancing past its window
    // makes it give up, which both drains the pending timer and proves the screen can no longer
    // strand the user on a spinner (the bug seen on the phone after an app restart).
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('No PCs found'), findsOneWidget);
  });
}
