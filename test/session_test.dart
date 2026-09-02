// The session against a real WebSocket server: what it does when the link dies, and what it keeps
// from `hello_ack`.
//
// The link half is here because of a socket that stops carrying traffic without ever erroring or
// closing. That is not a hypothetical: a phone that sleeps, or whose Wi-Fi radio drops into power save,
// leaves a HALF-OPEN TCP connection. `onDone` and `onError` never fire. The deck kept saying
// "online" while every press and every page swipe timed out one at a time, and the reconnect that
// would have fixed it in a second never started — which is what "no funciona, ni cambiar de página
// y de manual a auto" was.
//
// So this runs a real WebSocket server, answers `hello`, and then simply stops talking.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiboard_app/net/ws_layout_source.dart';

import 'tls_fake.dart';

/// A host that speaks just enough protocol to get a session open, and can then go quiet — or keep
/// its keepalive up, which is the case that must NOT trip the watchdog.
class _Host {
  final HttpServer server;
  WebSocket? socket;
  Timer? _pings;
  bool answer = true;

  /// Everything the phone sent, so a test can assert on the wire rather than on a mock.
  final received = <Map<String, dynamic>>[];

  /// What `hello_ack` offers (§2). Empty by default; the deck tests set it.
  List<Map<String, dynamic>> decks = const [];
  bool manualEnabled = true;

  /// §4.2: a navigating key (`deck:`, `mode:`) is answered with the layout of wherever the session
  /// landed rather than a `key_result` — the host moving the session's mode with nobody calling
  /// `set_mode`. Null means this host has no such key.
  Map<String, dynamic>? answerPressWith;

  _Host(this.server) {
    server.transform(WebSocketTransformer()).listen((ws) {
      socket = ws;
      ws.listen((raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        received.add(msg);
        if (!answer) {
          return; // gone quiet: the frames arrive and nothing comes back
        }
        if (msg['type'] == 'hello') {
          ws.add(
            jsonEncode({
              'v': 2,
              'type': 'hello_ack',
              'ok': true,
              'name': 'Test PC',
              'manualEnabled': manualEnabled,
              'decks': decks,
            }),
          );
        }
        if (msg['type'] == 'set_mode') {
          ws.add(jsonEncode({'v': 2, 'type': 'command_result', 'ok': true}));
        }
        if (msg['type'] == 'set_manual_enabled') {
          manualEnabled = msg['enabled'] == true;
          ws.add(
            jsonEncode({
              'v': 2,
              'type': 'command_result',
              'ok': true,
              'manualEnabled': manualEnabled,
              'showIntro': manualEnabled,
            }),
          );
          ws.add(
            jsonEncode({
              'v': 2,
              'type': 'manual_feature',
              'enabled': manualEnabled,
            }),
          );
        }
        if (msg['type'] == 'key' && answerPressWith != null) {
          final answer = Map<String, dynamic>.from(answerPressWith!);
          if (answer['type'] == 'key_result') answer['id'] ??= msg['id'];
          ws.add(jsonEncode(answer));
        }
      });
    });
  }

  /// TLS, because §2.2 is the only transport the client speaks — see `tls_fake.dart`.
  static Future<_Host> start() async =>
      _Host(await HttpServer.bindSecure('127.0.0.1', 0, fakeHostContext()));

  /// The 15 s keepalive of §4.4, sped up.
  void keepAlive(Duration every) {
    _pings = Timer.periodic(every, (_) => socket?.add(jsonEncode({'v': 2, 'type': 'ping'})));
  }

  Future<void> stop() async {
    _pings?.cancel();
    await server.close(force: true);
  }
}

void main() {
  test('Manual stays hidden until the host enables it', () async {
    final host = await _Host.start();
    addTearDown(host.stop);
    host.manualEnabled = false;

    final session = WsLayoutSource(
      ip: '127.0.0.1',
      port: host.server.port,
      token: 't',
      deviceId: 'd',
    );
    addTearDown(session.dispose);
    await session.connect();

    expect(session.manualEnabled, isFalse);
    await session.setMode('manual');
    expect(
      host.received.lastWhere((m) => m['type'] == 'set_mode')['mode'],
      'auto',
      reason: 'a hidden advanced feature cannot be entered through stale UI',
    );

    await session.setMode('manual', deckId: 'launcher');
    expect(
      host.received.lastWhere((m) => m['type'] == 'set_mode')['mode'],
      'manual',
      reason: 'Launcher is automatic and must not be hidden with fixed Manual decks',
    );

    expect(await session.setManualEnabled(true), isTrue);
    expect(session.manualEnabled, isTrue);
  });

  // F7's deck picker rests entirely on this: the list has been in every `hello_ack` since F1 and
  // the phone discarded it, which is why manual mode could only ever land on `decks[0]`.
  test('the decks offered in hello_ack are kept, and can be asked for by id', () async {
    final host = await _Host.start();
    addTearDown(host.stop);
    host.decks = const [
      {'id': 'obslive', 'name': 'OBS live', 'icon': 'obs'},
      {'id': 'f6', 'name': 'F6 bench', 'icon': 'work'},
    ];

    final session = WsLayoutSource(
      ip: '127.0.0.1',
      port: host.server.port,
      token: 't',
      deviceId: 'd',
    );
    addTearDown(session.dispose);
    await session.connect();

    expect(session.decks.map((d) => d.id), ['obslive', 'f6']);
    expect(session.decks.first.name, 'OBS live');

    await session.setMode('manual', deckId: 'f6');
    final sent = host.received.lastWhere((m) => m['type'] == 'set_mode');
    expect(sent['mode'], 'manual');
    expect(sent['deckId'], 'f6', reason: 'without the id the host falls back to decks[0]');
  });

  test('a host with no decks leaves the list empty rather than throwing', () async {
    final host = await _Host.start();
    addTearDown(host.stop);

    final session = WsLayoutSource(
      ip: '127.0.0.1',
      port: host.server.port,
      token: 't',
      deviceId: 'd',
    );
    addTearDown(session.dispose);
    await session.connect();

    expect(session.decks, isEmpty);
  });

  test('silence from the host is a dropped link, even when the socket says otherwise', () async {
    final host = await _Host.start();
    addTearDown(host.stop);

    final session = WsLayoutSource(
      ip: '127.0.0.1',
      port: host.server.port,
      token: 't',
      deviceId: 'd',
      silenceLimit: const Duration(milliseconds: 300),
    );
    addTearDown(session.dispose);

    expect(await session.connect(), 'Test PC');
    expect(session.currentStatus, SessionStatus.online);

    // The host goes quiet. Nothing is closed and nothing errors — the socket is still "open".
    host.answer = false;
    final wentOffline = session.status.firstWhere((s) => s != SessionStatus.online);
    expect(
      await wentOffline.timeout(const Duration(seconds: 2)),
      SessionStatus.offline,
      reason: 'the link has to be called dead from the silence, since nothing else reports it',
    );
  });

  test('a host that keeps pinging is never called dead', () async {
    final host = await _Host.start();
    addTearDown(host.stop);

    final session = WsLayoutSource(
      ip: '127.0.0.1',
      port: host.server.port,
      token: 't',
      deviceId: 'd',
      silenceLimit: const Duration(milliseconds: 300),
    );
    addTearDown(session.dispose);

    await session.connect();
    host.keepAlive(const Duration(milliseconds: 80));

    // Long enough for the watchdog to have fired several times over if the pings did not count.
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(session.currentStatus, SessionStatus.online);
  });

  test('a saved session rediscovers the paired host after its DHCP address changes', () async {
    final host = await _Host.start();
    addTearDown(host.stop);

    // Reserve and release a local port so the first connection is reliably refused. It models the
    // old DHCP address stored on the phone, while the resolver returns the host's current address.
    final dead = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = dead.port;
    await dead.close();
    var resolutions = 0;
    ({String ip, int port})? remembered;
    final session = WsLayoutSource(
      ip: '127.0.0.1',
      port: deadPort,
      token: 't',
      deviceId: 'd',
      endpointResolver: () async {
        resolutions++;
        return (ip: '127.0.0.1', port: host.server.port);
      },
      onEndpointConnected: (ip, port, _) async => remembered = (ip: ip, port: port),
    );
    addTearDown(session.dispose);

    await expectLater(session.connect(), throwsA(isA<HelloException>()));
    session.reconnectLater();
    await session.status
        .firstWhere((status) => status == SessionStatus.online)
        .timeout(const Duration(seconds: 5));

    expect(resolutions, 1);
    expect(session.port, host.server.port);
    expect(remembered?.port, host.server.port);
  });

  /// The mode the reconnect restores has to be the mode the session is actually IN. A `mode:` or
  /// `deck:` key moves it on the host and never went through `setMode`, so the phone kept replaying
  /// a mode the user had left minutes ago — and a manual session gets no auto pushes at all, so
  /// auto mode simply stopped updating until the app was restarted.
  test('the mode a key changed is the mode the reconnect restores', () async {
    final host = await _Host.start();
    addTearDown(host.stop);

    final session = WsLayoutSource(
      ip: '127.0.0.1',
      port: host.server.port,
      token: 't',
      deviceId: 'd',
      silenceLimit: const Duration(milliseconds: 300),
    );
    addTearDown(session.dispose);

    // Into a deck with the mode toggle, then back to auto with a `mode:auto` KEY.
    await session.connect();
    await session.setMode('manual', deckId: 'launcher');
    host.answerPressWith = {
      'v': 2,
      'type': 'layout',
      'mode': 'auto',
      'source': {'kind': 'profile', 'id': 'explorer', 'appName': 'Explorador de Windows'},
      'grid': {'rows': 5, 'cols': 3},
      'page': 0,
      'pages': 1,
      'keys': <Map<String, dynamic>>[],
    };
    await session.pressResult(pos: 0, press: 'short');

    // The link drops and comes back, which is what a phone in a pocket does all day.
    host.received.clear();
    host.answer = false;
    await session.status.firstWhere((s) => s != SessionStatus.online);
    host.answer = true;
    await session.status
        .firstWhere((s) => s == SessionStatus.online)
        .timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      host.received.where((m) => m['type'] == 'set_mode'),
      isEmpty,
      reason: 'the session is in auto — putting it back on a deck is what froze it',
    );
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('an app layout arriving after Launcher key_result keeps reconnect in Auto', () async {
    final host = await _Host.start();
    addTearDown(host.stop);

    final session = WsLayoutSource(
      ip: '127.0.0.1',
      port: host.server.port,
      token: 't',
      deviceId: 'd',
      silenceLimit: const Duration(milliseconds: 300),
    );
    addTearDown(session.dispose);

    await session.connect();
    await session.setMode('manual', deckId: 'launcher');
    host.answerPressWith = {'v': 2, 'type': 'key_result', 'ok': true};
    await session.pressResult(pos: 1, press: 'short');

    final receivedAuto = session.layouts().firstWhere((layout) => layout.mode == 'auto');
    host.socket!.add(
      jsonEncode({
        'v': 2,
        'type': 'layout',
        'mode': 'auto',
        'source': {'kind': 'profile', 'id': 'notepad', 'appName': 'Notepad'},
        'grid': {'rows': 5, 'cols': 3},
        'page': 0,
        'pages': 1,
        'keys': <Map<String, dynamic>>[],
      }),
    );
    await receivedAuto;

    host.received.clear();
    host.answer = false;
    await session.status.firstWhere((s) => s != SessionStatus.online);
    host.answer = true;
    await session.status
        .firstWhere((s) => s == SessionStatus.online)
        .timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      host.received.where((m) => m['type'] == 'set_mode'),
      isEmpty,
      reason: 'the selected app layout made Auto the authoritative session state',
    );
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('choosing a window keeps reconnect in Auto before its layout arrives', () async {
    final host = await _Host.start();
    addTearDown(host.stop);

    final session = WsLayoutSource(
      ip: '127.0.0.1',
      port: host.server.port,
      token: 't',
      deviceId: 'd',
      silenceLimit: const Duration(milliseconds: 300),
    );
    addTearDown(session.dispose);

    await session.connect();
    await session.setMode('manual', deckId: 'work');
    host.received.clear();
    await session.focusWindow(42);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      host.received.where((m) => m['type'] == 'focus_window').single['id'],
      42,
    );

    // Lose the connection before the foreground watcher can publish the selected app. The local
    // intent must already be Auto, or reconnect would resurrect the fixed Manual deck.
    host.received.clear();
    host.answer = false;
    await session.status.firstWhere((s) => s != SessionStatus.online);
    host.answer = true;
    await session.status
        .firstWhere((s) => s == SessionStatus.online)
        .timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      host.received.where((m) => m['type'] == 'set_mode'),
      isEmpty,
      reason: 'an explicit app choice belongs to Auto even if its layout was delayed',
    );
  }, timeout: const Timeout(Duration(seconds: 20)));

  test(
    'a session request that goes unanswered marks the link down instead of throwing',
    () async {
      final host = await _Host.start();
      addTearDown(host.stop);

      final session = WsLayoutSource(
        ip: '127.0.0.1',
        port: host.server.port,
        token: 't',
        deviceId: 'd',
        // Long, so this test is about the request timeout and not about the watchdog beating it.
        silenceLimit: const Duration(seconds: 30),
      );
      addTearDown(session.dispose);

      await session.connect();
      host.answer = false;

      // The mode toggle calls this from a tap and does not catch — an 8 s TimeoutException escaping
      // here is an unhandled error in the widget tree, and the user sees a button that does nothing.
      await expectLater(session.setMode('manual'), completes);
      expect(session.currentStatus, isNot(SessionStatus.online));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
