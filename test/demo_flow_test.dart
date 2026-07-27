// F1 replaced the FP-era MockDiscovery/instant-pairing with real mDNS (nsd) and a real
// pair_request/pair_confirm WebSocket round trip — neither of which exist in a test sandbox. So
// this file now covers two narrower, still-real things instead of one fake end-to-end run:
//   A) DiscoverScreen renders hosts from an injected Discovery and navigates on tap.
//   B) PairingCodeScreen's full code-entry -> confirm -> DeckScreen path, against an injected
//      Pairing fake (the real PairingClient itself was already verified against the actual
//      compiled host over a live WebSocket — see the project's manual verification notes).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiboard_app/mock/mock_layout_source.dart';
import 'package:kiboard_app/net/discovered_host.dart';
import 'package:kiboard_app/net/discovery.dart';
import 'package:kiboard_app/net/pairing_client.dart';
import 'package:kiboard_app/ui/pair/discover_screen.dart';
import 'package:kiboard_app/ui/pair/pairing_code_screen.dart';

class FakeDiscovery implements Discovery {
  final List<DiscoveredHost> hosts;
  FakeDiscovery(this.hosts);

  @override
  Future<List<DiscoveredHost>> discover() async => hosts;
}

class FakePairing implements Pairing {
  bool codeRequested = false;
  String? confirmedWith;

  @override
  Future<int> requestCode({required String device, required String platform}) async {
    codeRequested = true;
    return 120;
  }

  @override
  Future<PairingResult> confirmCode(String code) async {
    confirmedWith = code;
    if (code != '418203') throw const PairingException('bad_code');
    return const PairingResult(token: 'fake-token', deviceId: 'fake-device', hostName: "M3X's PC");
  }

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

void main() {
  testWidgets('DiscoverScreen lists hosts and navigates to pairing on tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: DiscoverScreen(discovery: FakeDiscovery([_host]))),
    );
    await tester.pumpAndSettle();

    expect(find.text("M3X's PC"), findsOneWidget);
    await tester.tap(find.text("M3X's PC"));
    // Navigating here creates a real PairingClient that tries to open an actual socket to
    // 127.0.0.1:8770 (nothing is listening in a test sandbox) — don't pumpAndSettle, its
    // still-loading spinner animates forever while that connection attempt hangs/fails.
    await tester.pump(); // start the push transition
    await tester.pump(const Duration(milliseconds: 300)); // let it finish

    expect(find.text('"M3X\'s PC" wants to connect'), findsOneWidget);
  });

  testWidgets('DiscoverScreen shows a rescan option when nothing is found', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: DiscoverScreen(discovery: FakeDiscovery(const []))),
    );
    await tester.pumpAndSettle();

    expect(find.text('No PCs found on this network yet.'), findsOneWidget);
    expect(find.text('Scan again'), findsOneWidget);
  });

  testWidgets('PairingCodeScreen: entering the right code pairs and opens the deck', (tester) async {
    final fake = FakePairing();
    await tester.pumpWidget(
      MaterialApp(
        home: PairingCodeScreen.withClient(
          host: _host,
          client: fake,
          // The real screen opens a WsLayoutSource here; a widget test has no host, so the
          // fixture-backed source stands in. What this covers is the navigation — the socket
          // itself is covered by test/manual_pairing_smoke.dart against a running host.
          openSession: (_) async => MockLayoutSource(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(fake.codeRequested, isTrue);

    await tester.enterText(find.byType(TextField), '418203');
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(fake.confirmedWith, '418203');
    // Successful pairing navigates to the deck screen (auto-mode Photoshop layout from fixtures).
    expect(find.text('Adobe Photoshop'), findsOneWidget);
  });

  testWidgets('PairingCodeScreen: a wrong code shows the host error, not a mock string', (tester) async {
    final fake = FakePairing();
    await tester.pumpWidget(
      MaterialApp(home: PairingCodeScreen.withClient(host: _host, client: fake)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong code — check the PC screen and try again.'), findsOneWidget);
  });
}
