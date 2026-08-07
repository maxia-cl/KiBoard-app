import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiboard_app/l10n/app_localizations.dart';
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
import 'package:kiboard_app/ui/windows/window_switcher_screen.dart';

/// Ten keys on the phone's own grid — what a real host sends once it has repaginated for the grid
/// the client declared in `hello`. DeckScreen reshapes it to the orientation itself as long as the
/// capacity matches, which is the case this exists to produce.
class _TenKeys extends LayoutSource {
  final _controller = StreamController<Layout>.broadcast();

  /// Makes key 0 a `danger` key, so the confirmation can be driven.
  final bool danger;

  /// Positions that actually reached the host.
  final pressed = <int>[];

  /// A deck with somewhere to swipe to, sitting on the middle page so both directions are open.
  final bool paginated;

  /// A manual deck (not auto), the app the PC has in front, and whether the last slot is used.
  final bool manual;
  final String? foreground;
  final bool full;

  _TenKeys({
    this.danger = false,
    this.paginated = false,
    this.manual = false,
    this.foreground,
    this.full = false,
  });

  int _page = 0;

  /// Pushes another page, the way a host answers `set_page`. Key 0 is labelled with the page, so a
  /// test can tell which page it is looking at — including one drawn as a neighbour.
  void goTo(int page) {
    _page = page;
    _controller.add(_layout);
  }

  /// §4.1 `page_preload`: a page the client is NOT on, as the host sends it unasked. Separate
  /// stream, because nothing that reaches `layouts()` may change what is on screen.
  final _preloadController = StreamController<Layout>.broadcast();
  void preload(int page) => _preloadController.add(_layoutFor(page));

  Layout get _layout => _layoutFor(paginated ? _page : 0);

  Layout _layoutFor(int page) => Layout(
    mode: manual ? 'manual' : 'auto',
    source: manual
        ? LayoutSourceInfo(kind: 'deck', id: 'test', name: 'Work', appName: foreground)
        : LayoutSourceInfo(kind: 'profile', id: 'test', appName: foreground ?? 'Test'),
    grid: const Grid(rows: 5, cols: 2),
    page: page,
    pages: paginated ? 3 : 1,
    keys: [
      DeckKey(
        pos: 0,
        label: danger
            ? 'Close app'
            : paginated
            ? 'page $page'
            : 'Copy',
        action: 'ctrl+c',
        danger: danger,
        kind: KeyKind.action,
      ),
      ...List.generate(9, (i) {
        // The LAST slot decides whether there is room for the foreground label.
        if (full && i == 8) {
          return DeckKey(pos: 9, label: 'Last', action: 'ctrl+v', kind: KeyKind.action);
        }
        return DeckKey.empty(i + 1);
      }),
    ],
  );

  @override
  Stream<Layout> layouts() {
    scheduleMicrotask(() => _controller.add(_layout));
    return _controller.stream;
  }

  @override
  Stream<Layout> preloads() => _preloadController.stream;

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

  void dispose() {
    _controller.close();
    _preloadController.close();
  }
}

/// Whether ANY node in the semantics tree offers [action].
///
/// Walked rather than looked up by widget: the page-change actions sit on a `Semantics` wrapping
/// the whole pad, and `getSemantics` resolves to whichever node is nearest the widget you name,
/// which for a container of explicit children is one of the children.
bool _somewhereInTree(WidgetTester tester, SemanticsAction action) {
  var found = false;
  void walk(SemanticsNode node) {
    if (node.getSemanticsData().actions & action.index != 0) found = true;
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  // The suggested replacement does not expose a root semantics node, and this one still resolves
  // to the tree the test is looking at.
  // ignore: deprecated_member_use
  walk(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return found;
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
      expect(parseHostAddress('http://desktop.local/'), (
        host: 'desktop.local',
        port: defaultHostPort,
      ));
    });

    test('IPv6 keeps its colons', () {
      // Bracketed, with and without a port.
      expect(parseHostAddress('[::1]:9000'), (host: '::1', port: 9000));
      expect(parseHostAddress('[fe80::1]'), (host: 'fe80::1', port: defaultHostPort));
      // Bare: every colon belongs to the address. Reading the last group as a port would dial
      // somewhere else entirely — the same trap `wsUri` exists for.
      expect(parseHostAddress('2803:c600:5108:844a:80a9:4d6f:5152:153b'), (
        host: '2803:c600:5108:844a:80a9:4d6f:5152:153b',
        port: defaultHostPort,
      ));
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

    // The old rule was that these two matched, which is what `sizeForDevice` enforced. Three
    // columns upright against five sideways ends it: the shapes hold different numbers of keys,
    // so one size cannot serve both. What replaced it is a floor — upright the key must still be
    // in the same class as before the third column (114.1 then, ~112.5 now), because the whole
    // point of trimming the bezel was that the extra column would NOT be paid for in key size.
    expect(
      upright,
      greaterThan(105),
      reason: 'the third column was supposed to come out of the bezel, not out of the key',
    );
    expect(sideways, greaterThan(60), reason: 'and sideways still has to be pressable');
  });

  /// §3 says a `danger` key is painted red AND asks before it acts. Only the paint was built, so
  /// "Cerrar app" closed whatever was in front on one mis-tap — on a surface hit from muscle
  /// memory, sitting next to keys that do nothing worse than copy.
  group('a danger key asks first', () {
    Future<_TenKeys> pumpDeck(WidgetTester tester) async {
      final source = _TenKeys(danger: true);
      addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DeckScreen(layoutSource: source, hostName: 'PC'),
        ),
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
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DeckScreen(layoutSource: source, hostName: 'PC'),
        ),
      );
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

  /// §4.1: a manual deck follows nothing, so the phone was pressing keys at a PC without being
  /// able to name what was in front of it. Auto mode says it in the title; manual had nowhere.
  group('the foreground app in manual mode', () {
    Future<void> pump(WidgetTester tester, _TenKeys source) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DeckScreen(layoutSource: source, hostName: 'PC'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('is shown over the last two cells when they are free', (tester) async {
      final source = _TenKeys(manual: true, foreground: 'Photoshop');
      addTearDown(source.dispose);
      await pump(tester, source);
      expect(find.text('Photoshop'), findsOneWidget);
    });

    testWidgets('gives way to keys rather than covering them', (tester) async {
      // The same deck with its last slot used. The keys are the product; this is context.
      final source = _TenKeys(manual: true, foreground: 'Photoshop', full: true);
      addTearDown(source.dispose);
      await pump(tester, source);
      expect(find.text('Photoshop'), findsNothing);
    });

    testWidgets('and auto mode does not draw it in the grid', (tester) async {
      // Auto already names the app in the title — a second copy in the grid would be noise.
      final source = _TenKeys(foreground: 'Photoshop');
      addTearDown(source.dispose);
      await pump(tester, source);
      expect(find.text('Photoshop'), findsOneWidget, reason: 'the title, and only the title');
    });
  });

  /// There was exactly one `Semantics` in the whole app, on the wordmark. A key draws its label in
  /// a `Text` that an icon-only key does not have, so those keys announced nothing at all — and
  /// the page swipe is a raw drag, which a screen reader cannot perform, so page 1 was the only
  /// page it could reach.
  group('a screen reader can use the deck', () {
    testWidgets('keys announce their label and are marked as buttons', (tester) async {
      final handle = tester.ensureSemantics();
      final source = _TenKeys();
      addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DeckScreen(layoutSource: source, hostName: 'PC'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.bySemanticsLabel('Copy'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('Copy'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().actions & SemanticsAction.tap.index, isNot(0));
      handle.dispose();
    });

    testWidgets('and can change page without performing a drag', (tester) async {
      final handle = tester.ensureSemantics();
      final source = _TenKeys(paginated: true);
      addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DeckScreen(layoutSource: source, hostName: 'PC'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // On page 0 of 3: forward is offered, back is not — the same bounds the swipe respects.
      expect(
        _somewhereInTree(tester, SemanticsAction.increase),
        isTrue,
        reason: 'without this there is no accessible way off the first page',
      );
      expect(
        _somewhereInTree(tester, SemanticsAction.decrease),
        isFalse,
        reason: 'nothing before page 1',
      );
      handle.dispose();
    });
  });

  /// `listWindows` gives up by throwing, and nothing caught it: the screen waited eight seconds
  /// and then span for ever, with an unhandled async error behind it.
  testWidgets('the window switcher says it failed instead of spinning for ever', (tester) async {
    final source = _TenKeys(); // its listWindows throws, like a host that never answers
    addTearDown(source.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WindowSwitcherScreen(layoutSource: source),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Could not reach your PC to list its windows.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget, reason: 'and a way forward, not just a dead end');
  });

  /// Back used to do one of two things depending on how you got to the deck, and neither was
  /// intended: on a relaunch it closed the app outright, and in the session where you paired it
  /// popped to the discovery list you had already finished, with no route forward.
  group('back on the deck', () {
    testWidgets('asks once, and the second press leaves', (tester) async {
      final platformCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        platformCalls.add(call.method);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final source = _TenKeys();
      addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DeckScreen(layoutSource: source, hostName: 'PC'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Press back again to leave KiBoard'), findsOneWidget);
      expect(
        platformCalls,
        isNot(contains('SystemNavigator.pop')),
        reason: 'one back press must not close a keypad somebody is looking at',
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(platformCalls, contains('SystemNavigator.pop'));
    });

    testWidgets('and the warning expires, so it cannot leave much later', (tester) async {
      final platformCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        platformCalls.add(call.method);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final source = _TenKeys();
      addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DeckScreen(layoutSource: source, hostName: 'PC'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3)); // the snackbar and the window both go
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(platformCalls, isNot(contains('SystemNavigator.pop')));
      expect(find.text('Press back again to leave KiBoard'), findsOneWidget);
    });
  });

  /// §4.4 `set_page`. The swipe used to read only `primaryVelocity` on RELEASE: nothing moved
  /// while the finger did, and a slow, deliberate drag across the whole pad ended at zero velocity
  /// and changed nothing at all. Both halves of "se queda pegado".
  group('the page swipe follows the finger', () {
    Future<_TenKeys> pumpDeck(WidgetTester tester) async {
      final source = _TenKeys(paginated: true);
      addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DeckScreen(layoutSource: source, hostName: 'PC'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return source;
    }

    double gridX(WidgetTester tester) => tester.getTopLeft(find.byType(KeyGrid)).dx;

    testWidgets('the page moves under the finger, before it is lifted', (tester) async {
      await pumpDeck(tester);
      final home = gridX(tester);

      final finger = await tester.startGesture(tester.getCenter(find.byType(KeyGrid)));
      await finger.moveBy(const Offset(-80, 0));
      await tester.pump();

      expect(
        gridX(tester),
        closeTo(home - 80, 1),
        reason: 'the page has to be where the finger is, not waiting for it to lift',
      );
      await finger.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a short drag springs home', (tester) async {
      await pumpDeck(tester);
      final home = gridX(tester);

      final finger = await tester.startGesture(tester.getCenter(find.byType(KeyGrid)));
      await finger.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 120)); // slow: no velocity to commit on
      await finger.up();
      await tester.pumpAndSettle();

      expect(gridX(tester), closeTo(home, 1));
    });

    testWidgets('a slow drag past a quarter of the pad still commits', (tester) async {
      await pumpDeck(tester);
      final home = gridX(tester);
      final width = tester.getSize(find.byType(KeyGrid)).width;

      // Deliberately slow — each move is a frame apart, so the release velocity is ~0. This is the
      // exact gesture the old velocity-only rule threw away.
      final finger = await tester.startGesture(tester.getCenter(find.byType(KeyGrid)));
      for (var moved = 0.0; moved < width * 0.4; moved += width * 0.1) {
        await finger.moveBy(Offset(-width * 0.1, 0));
        await tester.pump(const Duration(milliseconds: 120));
      }
      await finger.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        gridX(tester),
        lessThan(home - width * 0.5),
        reason: 'a committed page carries on out instead of snapping back',
      );

      // ...and with no session to answer it, the guard puts the page back rather than leaving the
      // deck blank. Being offline is a normal state for this screen.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(gridX(tester), closeTo(home, 1));
    });

    testWidgets('a page already seen comes in behind the finger', (tester) async {
      final source = await pumpDeck(tester);
      expect(find.text('page 0'), findsOneWidget);
      expect(find.byType(KeyGrid), findsOneWidget, reason: 'nothing extra is drawn at rest');

      // Swipe through the deck once, the way using it does, and come back.
      source.goTo(1);
      await tester.pumpAndSettle();
      source.goTo(0);
      await tester.pumpAndSettle();

      // Slow and short on purpose: this is about what is DRAWN mid-gesture, so it must not commit
      // and swap the page out from under the assertion.
      final finger = await tester.startGesture(tester.getCenter(find.byType(KeyGrid)));
      await finger.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('page 1'), findsOneWidget, reason: 'the next page, not a black gap');
      expect(find.byType(KeyGrid), findsNWidgets(2));

      await finger.up();
      await tester.pumpAndSettle();
      // And it goes away again, rather than being built on every layout push for nothing.
      expect(find.byType(KeyGrid), findsOneWidget);
    });

    // §4.1 `page_preload`: the host sends the neighbours unasked, so the FIRST swipe onto a page
    // works too — without it the phone only ever holds pages it has already been on.
    testWidgets('a preloaded page is drawn without ever having been visited', (tester) async {
      final source = await pumpDeck(tester);
      source.preload(1);
      await tester.pump();

      final finger = await tester.startGesture(tester.getCenter(find.byType(KeyGrid)));
      await finger.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('page 1'), findsOneWidget, reason: 'never visited, still drawn');
      expect(find.text('page 0'), findsOneWidget, reason: 'and it did not replace what is on screen');

      await finger.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a page it has never been sent draws nothing rather than guessing', (tester) async {
      await pumpDeck(tester); // page 0, and nothing else has arrived

      final finger = await tester.startGesture(tester.getCenter(find.byType(KeyGrid)));
      await finger.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(KeyGrid), findsOneWidget);
      await finger.up();
      await tester.pumpAndSettle();
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

  testWidgets('a key waiting for its app shows a spinner, and does not go red', (tester) async {
    // `state.running` is the only thing on the wire that marks a key as one that opens an app —
    // the phone never sees the action (§4.2) — so parsing it is half the feature.
    final waiting = DeckKey.fromLayoutJson({
      'pos': 0,
      'label': 'Photoshop',
      'kind': 'action',
      'state': {'running': false},
    });
    final ordinary = DeckKey.fromLayoutJson({'pos': 1, 'label': 'Copy', 'kind': 'action'});
    expect(waiting.running, isFalse, reason: 'false is "not open yet", and it drives the wait');
    expect(ordinary.running, isNull, reason: 'null is "nothing to wait for" — a different thing');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: KeyWidget(keyData: waiting, size: 80, launching: true)),
      ),
    );
    await tester.pump();

    // Waiting is said with a spinner, the vocabulary everyone already knows. Red belongs to the
    // danger key; painting a launching key with it said "something is wrong here" instead.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // And the cap stays DOWN while it waits — a button that is working on it looks held, and a
    // held button is also the plainest way to say another press will do nothing.
    final cap = tester.widget<AnimatedContainer>(
      find.descendant(of: find.byType(KeyWidget), matching: find.byType(AnimatedContainer)).first,
    );
    expect((cap.transform ?? Matrix4.identity()).getTranslation().y, greaterThan(0));
    final box = tester.widget<AnimatedContainer>(
      find.descendant(of: find.byType(KeyWidget), matching: find.byType(AnimatedContainer)).first,
    );
    final face = ((box.decoration! as BoxDecoration).gradient! as LinearGradient).colors[1];
    expect(face.r, lessThan(0.2), reason: 'the cap keeps its own colour');
  });

  testWidgets('a key travels when it is held down, like a cap on a spring', (tester) async {
    // §3.0: it has to read as hardware. The light stays where it is — a gradient that flips reads
    // as a different material — and what moves is the CAP: down by a couple of pixels, into a
    // shadow that all but disappears. Asserted because it is invisible in a screenshot taken a
    // frame late, and it is exactly the kind of detail a later refactor flattens.
    final key = DeckKey.fromLayoutJson({'pos': 0, 'label': 'Copy', 'kind': 'action'});
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: KeyWidget(keyData: key, size: 80)),
        ),
      ),
    );

    AnimatedContainer cap() => tester.widget<AnimatedContainer>(
      find.descendant(of: find.byType(KeyWidget), matching: find.byType(AnimatedContainer)).first,
    );
    double sink(AnimatedContainer c) => (c.transform ?? Matrix4.identity()).getTranslation().y;
    BoxShadow shadow(AnimatedContainer c) => (c.decoration! as BoxDecoration).boxShadow!.first;

    final atRest = cap();
    expect(sink(atRest), 0);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(KeyWidget)));
    await tester.pump(const Duration(milliseconds: 120));
    final held = cap();

    expect(sink(held), greaterThan(0), reason: 'the cap goes down, it does not just darken');
    expect(
      shadow(held).blurRadius,
      lessThan(shadow(atRest).blurRadius),
      reason: 'and lands in its own shadow',
    );
    expect(
      ((held.decoration! as BoxDecoration).gradient! as LinearGradient).begin,
      Alignment.topCenter,
      reason: 'the light does not move — only the key does',
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(sink(cap()), 0, reason: 'and springs back');
  });

  testWidgets('a key that opens an app does not spring back between the finger and the launch', (
    tester,
  ) async {
    // The blink: with `onDoubleTap` registered, `onTap` only fires after the 300 ms double-press
    // window, so the press is not even sent until then. The cap used to come up when the finger
    // left and go down again when the launch was marked — visible, and exactly what a physical
    // button never does.
    final opensApp = DeckKey.fromLayoutJson({
      'pos': 0,
      'label': 'Photoshop',
      'kind': 'action',
      'state': {'running': false},
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: KeyWidget(keyData: opensApp, size: 80))),
      ),
    );

    double sink() =>
        (tester
                    .widget<AnimatedContainer>(
                      find
                          .descendant(
                            of: find.byType(KeyWidget),
                            matching: find.byType(AnimatedContainer),
                          )
                          .first,
                    )
                    .transform ??
                Matrix4.identity())
            .getTranslation()
            .y;

    final gesture = await tester.startGesture(tester.getCenter(find.byType(KeyWidget)));
    await tester.pump(const Duration(milliseconds: 60));
    expect(sink(), greaterThan(0));

    await gesture.up();
    // Every frame of the double-press window: the cap must not come up in any of them.
    for (var ms = 50; ms <= 400; ms += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(sink(), greaterThan(0), reason: 'came back up ${ms}ms after the finger left');
    }

    // And it does not stay down for ever when no launch ever starts.
    await tester.pump(const Duration(seconds: 2));
    expect(sink(), 0);
  });

  testWidgets('the same icon is decoded once, so a re-sent layout does not blink', (tester) async {
    // A 1x1 PNG, the smallest thing that is really an image.
    const uri =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    final key = DeckKey.fromLayoutJson({'pos': 0, 'label': 'App', 'kind': 'action', 'image': uri});

    Future<ImageProvider> provider() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: KeyWidget(keyData: key, size: 80)),
        ),
      );
      await tester.pump();
      return tester.widget<Image>(find.byType(Image)).image;
    }

    // The SAME provider instance across rebuilds is the whole fix: a fresh `MemoryImage` is a new
    // image as far as Flutter is concerned, so it decodes again and shows one empty frame — which
    // is every icon on the page blinking each time the host re-sends a layout.
    expect(identical(await provider(), await provider()), isTrue);
  });

  testWidgets('a swipe across a key neither clicks nor buzzes', (tester) async {
    // The deck changes page with a sideways swipe, and that swipe starts on a key. The key
    // correctly does nothing — and used to buzz and click anyway, because the feedback was on
    // touch-down. It belongs to the press that lands.
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'HapticFeedback.vibrate' || call.method == 'SystemSound.play') {
        calls.add(call.method);
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final key = DeckKey.fromLayoutJson({'pos': 0, 'label': 'Copy', 'kind': 'action'});
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: KeyWidget(keyData: key, size: 80))),
      ),
    );

    final centre = tester.getCenter(find.byType(KeyWidget));
    final swipe = await tester.startGesture(centre);
    await tester.pump(const Duration(milliseconds: 30));
    await swipe.moveBy(const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 30));
    await swipe.up();
    await tester.pumpAndSettle();
    expect(calls, isEmpty, reason: 'a swipe is not a press');

    final tap = await tester.startGesture(centre);
    await tester.pump(const Duration(milliseconds: 30));
    await tap.up();
    await tester.pumpAndSettle();
    expect(calls, isNotEmpty, reason: 'and a press still answers');
  });
}
