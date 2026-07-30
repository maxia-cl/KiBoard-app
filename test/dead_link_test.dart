// A socket that stops carrying traffic without ever erroring or closing.
//
// This is not a hypothetical: a phone that sleeps, or whose Wi-Fi radio drops into power save,
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

/// A host that speaks just enough protocol to get a session open, and can then go quiet — or keep
/// its keepalive up, which is the case that must NOT trip the watchdog.
class _Host {
  final HttpServer server;
  WebSocket? socket;
  Timer? _pings;
  bool answer = true;

  _Host(this.server) {
    server.transform(WebSocketTransformer()).listen((ws) {
      socket = ws;
      ws.listen((raw) {
        if (!answer) return; // gone quiet: the frames arrive and nothing comes back
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        if (msg['type'] == 'hello') {
          ws.add(jsonEncode({'v': 2, 'type': 'hello_ack', 'ok': true, 'name': 'Test PC'}));
        }
      });
    });
  }

  static Future<_Host> start() async => _Host(await HttpServer.bind('127.0.0.1', 0));

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

  test('a session request that goes unanswered marks the link down instead of throwing', () async {
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
  }, timeout: const Timeout(Duration(seconds: 30)));
}
