import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../model/deck.dart';
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
  Stream<Map<String, dynamic>>? _messages;

  /// The page currently on screen. `pressKey` has to send it because the host resolves a press
  /// against (page, pos) — position alone is ambiguous once a deck has more than one page.
  int _page = 0;
  int _keyId = 0;

  /// Opens the socket and authenticates. Returns the host's display name.
  Future<String> connect() async {
    final channel = WebSocketChannel.connect(Uri.parse('ws://$ip:$port'));
    await channel.ready;
    _channel = channel;
    _messages = channel.stream
        .map((raw) => jsonDecode(raw as String) as Map<String, dynamic>)
        .asBroadcastStream();

    _send({
      'v': 2,
      'type': 'hello',
      'token': token,
      'deviceId': deviceId,
      'locale': locale,
      'grid': {'rows': grid.rows, 'cols': grid.cols},
    });
    final ack = await _messages!.firstWhere((m) => m['type'] == 'hello_ack');
    if (ack['ok'] != true) {
      throw HelloException(ack['error'] as String? ?? 'not_paired');
    }
    return ack['name'] as String? ?? '';
  }

  @override
  Stream<Layout> layouts() {
    return _messages!.where((m) => m['type'] == 'layout').map((m) {
      final layout = Layout.fromJson(m);
      _page = layout.page;
      return layout;
    });
  }

  @override
  Future<void> pressKey({required int pos, required String press}) =>
      pressResult(pos: pos, press: press);

  /// [pressKey] plus the host's answer, for callers that need to assert on it. A navigating key
  /// (folder/page) is answered with the new `layout` instead of a `key_result` — for navigation
  /// the layout IS the result — so waiting for either keeps both cases from hanging. The layout
  /// also reaches the UI through [layouts], which shares this broadcast stream.
  Future<Map<String, dynamic>> pressResult({required int pos, required String press}) async {
    final id = '${++_keyId}';
    _send({'v': 2, 'type': 'key', 'id': id, 'page': _page, 'pos': pos, 'press': press});
    return _messages!.firstWhere(
      (m) => (m['type'] == 'key_result' && m['id'] == id) || m['type'] == 'layout',
    );
  }

  @override
  Future<void> setMode(String mode, {String? deckId}) async {
    _send({
      'v': 2,
      'type': 'set_mode',
      'mode': mode,
      'deckId': ?deckId,
    });
    await _messages!.firstWhere((m) => m['type'] == 'layout' || m['type'] == 'command_result');
  }

  /// Protocol §4.4 `set_page` — swiping between the pages of a deck.
  Future<void> setPage(int page) async {
    _send({'v': 2, 'type': 'set_page', 'page': page});
    await _messages!.firstWhere((m) => m['type'] == 'layout' || m['type'] == 'command_result');
  }

  @override
  Future<WindowsPage> listWindows(int page) async {
    _send({'v': 2, 'type': 'list_windows', 'page': page});
    final msg = await _messages!.firstWhere((m) => m['type'] == 'windows');
    return WindowsPage.fromJson(msg);
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
    await _channel?.sink.close();
  }
}
