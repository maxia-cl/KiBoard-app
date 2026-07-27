import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../model/deck.dart';
import 'discovered_host.dart';
import 'layout_source.dart';

/// Thrown when `hello` is rejected: revoked, invalid_token, protocol_too_old (protocol §5).
class HelloException implements Exception {
  final String code;
  const HelloException(this.code);
  @override
  String toString() => code;
}

/// The real [LayoutSource]: one WebSocket to a paired host, speaking protocol v2 (§4).
///
/// Drop-in replacement for `MockLayoutSource` — the wire shape the mock read from fixtures is the
/// shape the host actually sends, which is what phase FP's seam was for.
class WsLayoutSource implements LayoutSource {
  WsLayoutSource({
    required this.ip,
    required this.port,
    required this.token,
    required this.deviceId,
    this.grid = const Grid(rows: 3, cols: 5),
    this.locale = 'es',
  });

  final String ip;
  final int port;
  final String token;
  final String deviceId;

  /// Declared in `hello`; the host paginates every deck to it, so the phone never repaginates.
  final Grid grid;
  final String locale;

  WebSocketChannel? _channel;

  /// Owned subscription to the socket, cancelled only in [dispose]. See the note in
  /// [PairingClient]: `asBroadcastStream` tears the socket down as soon as the last `firstWhere`
  /// matches and unsubscribes, which is exactly what happens between two session calls.
  StreamSubscription<dynamic>? _socket;
  final _incoming = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get _messages => _incoming.stream;

  /// The page currently on screen. `pressKey` has to send it because the host resolves a press
  /// against (page, pos) — position alone is ambiguous once a deck has more than one page.
  int _page = 0;
  int _keyId = 0;

  /// The most recent layout, replayed to every new subscriber of [layouts].
  ///
  /// Without it the deck screen opens on a spinner it never leaves: `setMode` consumes the very
  /// layout it triggered, and the screen only subscribes afterwards, during the navigation that
  /// follows. A broadcast stream drops what arrives with no listener — and in manual mode the host
  /// has no reason to push another one, so the first layout is the ONLY layout.
  Layout? _last;

  /// How long any step of the handshake may take before it is called a failure. A LAN round trip
  /// is milliseconds; anything near this is a dead host, a wrong address, or a firewall silently
  /// dropping the SYN. Without it a failed connect leaves the UI spinning forever, because a TCP
  /// connect to an unreachable address neither completes nor throws for minutes.
  static const handshakeTimeout = Duration(seconds: 8);

  /// Opens the socket and authenticates. Returns the host's display name.
  /// Throws [HelloException] with a short code on any failure, never hangs.
  Future<String> connect() async {
    final channel = WebSocketChannel.connect(wsUri(ip, port));
    try {
      await channel.ready.timeout(handshakeTimeout);
    } on TimeoutException {
      throw const HelloException('connect_timeout');
    } catch (e) {
      throw HelloException('connect_failed: $e');
    }
    _channel = channel;
    _socket = channel.stream.listen(
      (raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        // Captured here, on the socket's own subscription, so a layout is remembered even when
        // nothing is listening to `layouts()` yet.
        if (msg['type'] == 'layout') {
          final layout = Layout.fromJson(msg);
          _last = layout;
          _page = layout.page;
        }
        _incoming.add(msg);
      },
      onError: _incoming.addError,
      onDone: () {
        if (!_incoming.isClosed) _incoming.close();
      },
    );

    // Subscribe BEFORE sending: the reply to a LAN round trip can land in the same turn, and a
    // broadcast stream discards anything that arrives while it has no listener.
    final acked = _messages.firstWhere((m) => m['type'] == 'hello_ack');
    _send({
      'v': 2,
      'type': 'hello',
      'token': token,
      'deviceId': deviceId,
      'locale': locale,
      'grid': {'rows': grid.rows, 'cols': grid.cols},
    });
    final Map<String, dynamic> ack;
    try {
      ack = await acked.timeout(handshakeTimeout);
    } on TimeoutException {
      throw const HelloException('hello_timeout');
    }
    if (ack['ok'] != true) {
      throw HelloException(ack['error'] as String? ?? 'not_paired');
    }
    return ack['name'] as String? ?? '';
  }

  @override
  Stream<Layout> layouts() async* {
    // Replay the current layout so a subscriber that arrives late still has something to draw.
    final cached = _last;
    if (cached != null) yield cached;
    yield* _messages.where((m) => m['type'] == 'layout').map(Layout.fromJson);
  }

  @override
  Future<void> pressKey({required int pos, required String press}) =>
      pressResult(pos: pos, press: press);

  /// [pressKey] plus the host's answer, for callers that need to assert on it. A navigating key
  /// (folder/page) is answered with the new `layout` instead of a `key_result` — for navigation
  /// the layout IS the result — so waiting for either keeps both cases from hanging. The layout
  /// also reaches the UI through [layouts], which shares this broadcast stream.
  Future<Map<String, dynamic>> pressResult({required int pos, required String press}) {
    final id = '${++_keyId}';
    final answered = _messages.firstWhere(
      (m) => (m['type'] == 'key_result' && m['id'] == id) || m['type'] == 'layout',
    );
    _send({'v': 2, 'type': 'key', 'id': id, 'page': _page, 'pos': pos, 'press': press});
    return answered;
  }

  @override
  Future<void> setMode(String mode, {String? deckId}) async {
    final replied = _replyTo();
    _send({
      'v': 2,
      'type': 'set_mode',
      'mode': mode,
      'deckId': ?deckId,
    });
    await replied.timeout(handshakeTimeout);
  }

  /// Protocol §4.4 `set_page` — swiping between the pages of a deck.
  Future<void> setPage(int page) async {
    final replied = _replyTo();
    _send({'v': 2, 'type': 'set_page', 'page': page});
    await replied.timeout(handshakeTimeout);
  }

  /// Subscribes for a session-control reply before the request goes out. Both `set_mode` and
  /// `set_page` are answered with the resulting `layout`, or a `command_result` when there is
  /// nothing to render.
  Future<Map<String, dynamic>> _replyTo() =>
      _messages.firstWhere((m) => m['type'] == 'layout' || m['type'] == 'command_result');

  @override
  Future<WindowsPage> listWindows(int page) async {
    final listed = _messages.firstWhere((m) => m['type'] == 'windows');
    _send({'v': 2, 'type': 'list_windows', 'page': page});
    return WindowsPage.fromJson(await listed.timeout(handshakeTimeout));
  }

  @override
  Future<void> focusWindow(int windowId) async {
    _send({'v': 2, 'type': 'focus_window', 'id': windowId});
  }

  /// Continuous input (§4.2 exception): trackpad, volume slider, dictation. Not keys — they carry
  /// no position, and the host validates each `kind` against a closed vocabulary. Fire-and-forget:
  /// a trackpad sends these at pointer rate and must never wait for a round trip.
  void sendInput(Map<String, dynamic> input) {
    _send({'v': 2, 'type': 'input', ...input});
  }

  void _send(Map<String, dynamic> message) {
    _channel!.sink.add(jsonEncode(message));
  }

  Future<void> dispose() async {
    await _socket?.cancel();
    _socket = null;
    if (!_incoming.isClosed) await _incoming.close();
    await _channel?.sink.close();
    _channel = null;
  }
}
