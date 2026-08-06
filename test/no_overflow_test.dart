// Every screen, at every size that actually happens, with nothing spilling off the edge.
//
// This exists because of a real one: F7's "no PCs found" copy fitted upright and overflowed the
// bottom by 28 px the moment the phone was held sideways — on the ONE screen a user reaches when
// nothing else is working. Eyeballing a screen in one orientation cannot catch that, and neither
// can a test that only asserts text is present: Flutter reports an overflow as an exception, so
// pumping each screen small enough and taking that exception is the whole check.
//
// The sizes are not decoration. Landscape is where a Column of prose runs out of height; 320x480
// is the smallest phone still shipping; and the 1.3 text scale is the accessibility setting that
// turns a comfortable layout into a broken one without any code changing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiboard_app/l10n/app_localizations.dart';

import 'package:kiboard_app/mock/mock_layout_source.dart';
import 'package:kiboard_app/net/discovered_host.dart';
import 'package:kiboard_app/net/discovery.dart';
import 'package:kiboard_app/net/pairing_client.dart';
import 'package:kiboard_app/ui/deck/deck_screen.dart';
import 'package:kiboard_app/ui/pair/discover_screen.dart';
import 'package:kiboard_app/ui/pair/pairing_code_screen.dart';
import 'package:kiboard_app/ui/windows/window_switcher_screen.dart';

class _Discovery implements Discovery {
  final List<DiscoveredHost> hosts;
  _Discovery(this.hosts);
  @override
  Future<List<DiscoveredHost>> discover() async => hosts;
}

class _Pairing implements Pairing {
  @override
  Future<int> requestCode({required String device, required String platform}) async => 120;
  @override
  Future<PairingResult> confirmCode(String code) async =>
      const PairingResult(token: 't', deviceId: 'd', hostName: 'h');
  @override
  Future<void> dispose() async {}
}

const _host = DiscoveredHost(
  id: 'a1b2c3d4',
  name: "M3X's PC",
  os: 'win',
  mode: 'auto',
  pairingOpen: true,
  ip: '127.0.0.1',
  port: 8770,
);

/// Sizes in LOGICAL pixels, which is what a widget test lays out in.
const _sizes = <String, Size>{
  'small portrait': Size(360, 640),
  // The one that broke: a phone held sideways has barely any height left for prose.
  'small landscape': Size(640, 360),
  'smallest phone still shipping': Size(320, 480),
};

void main() {
  /// Lays [build] out at every size, at normal and at accessibility text scale, and fails on the
  /// first thing that does not fit. `settle` is off for screens that animate forever (a spinner
  /// waiting on a socket that a test sandbox never gives them).
  Future<void> fitsEverywhere(
    WidgetTester tester,
    String what,
    Widget Function() build, {
    bool settle = true,
  }) async {
    for (final entry in _sizes.entries) {
      for (final scale in const [1.0, 1.3]) {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: entry.value, textScaler: TextScaler.linear(scale)),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: build(),
            ),
          ),
        );
        if (settle) {
          await tester.pumpAndSettle();
        } else {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }

        expect(
          tester.takeException(),
          isNull,
          reason: '$what does not fit a ${entry.key} (${entry.value}) at ${scale}x text',
        );
      }
    }
  }

  testWidgets('discovery, while it is still looking', (tester) async {
    await fitsEverywhere(
      tester,
      'the discovery screen',
      () => DiscoverScreen(discovery: _Discovery(const [])),
      settle: false,
    );
  });

  testWidgets('discovery, with nothing found — the screen that must never break', (tester) async {
    // A user only reads this one when everything else has already failed them.
    await fitsEverywhere(
      tester,
      'the empty discovery state',
      () => DiscoverScreen(discovery: _Discovery(const [])),
    );
  });

  testWidgets('discovery, with hosts listed', (tester) async {
    await fitsEverywhere(
      tester,
      'the host list',
      () => DiscoverScreen(discovery: _Discovery(const [_host, _host, _host])),
    );
  });

  testWidgets('the pairing code screen', (tester) async {
    await fitsEverywhere(
      tester,
      'the pairing screen',
      () => PairingCodeScreen.withClient(host: _host, client: _Pairing()),
    );
  });

  testWidgets('the deck itself', (tester) async {
    await fitsEverywhere(
      tester,
      'the deck',
      () => DeckScreen(layoutSource: MockLayoutSource(), hostName: "M3X's PC"),
      settle: false,
    );
  });

  testWidgets('the window switcher', (tester) async {
    await fitsEverywhere(
      tester,
      'the window switcher',
      () => WindowSwitcherScreen(layoutSource: MockLayoutSource()),
      settle: false,
    );
  });

  // The address sheet is the one place a keyboard and a form share a screen, which is exactly
  // where height runs out. It also earned its own regression: the first version overflowed by
  // 99,619 px because a Column in a bottom sheet has no height to be min of.
  testWidgets('the typed-address sheet, open', (tester) async {
    for (final entry in _sizes.entries) {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: entry.value),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiscoverScreen(discovery: _Discovery(const [])),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // On the smallest phone the explanation scrolls, so the button under it can start below the
      // fold. That is fine — the link at the bottom of the screen is always there — but the test
      // has to scroll to it like a user would.
      await tester.ensureVisible(find.text('Enter its address'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter its address'));
      await tester.pumpAndSettle();

      expect(
        find.text("Your PC's address"),
        findsOneWidget,
        reason: 'the sheet should be open on a ${entry.key}',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'the address sheet does not fit a ${entry.key}',
      );

      // Close it, so the next size starts from the same place.
      Navigator.of(tester.element(find.text("Your PC's address"))).pop();
      await tester.pumpAndSettle();
    }
  });
}
