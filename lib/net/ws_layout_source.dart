import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../model/deck.dart';
import 'discovered_host.dart';
import 'layout_source.dart';
import 'pinned_socket.dart';
import 'trace.dart';

/// Thrown when `hello` is rejected: revoked, invalid_token, protocol_too_old (protocol §5).
class HelloException implements Exception {
  final String code;
  const HelloException(this.code);
  @override
  String toString() => code;

  /// The host will never accept this token again, so retrying is pointless and the saved session
  /// has to go. Anything else (a timeout, a dropped Wi-Fi) is worth another attempt.
  bool get isFatal => code == 'revoked' || code == 'invalid_token' || code == 'not_paired';
}

/// What the deck screen shows about the link. A phone on Wi-Fi loses its connection constantly —
/// screen off, a walk to another room, a router hiccup — so "connected" is a state to display and
/// recover from, not an assumption.
enum SessionStatus { connecting, online, offline, dead }

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
    Grid grid = const Grid(rows: 3, cols: 5),
    String? locale,
    this.certificate,
    this.silenceLimit = const Duration(seconds: 40),
    // ignore: prefer_initializing_formals -- `grid` is public and mutable behind a getter
  }) : _grid = grid,
       locale = locale ?? deviceLocale();

  final String ip;
  final int port;
  final String token;
  final String deviceId;

  /// Declared in `hello` and re-declared with `set_grid` on rotation; the host paginates every
  /// deck to it, so the phone never repaginates.
  Grid get grid => _grid;
  Grid _grid;
  final String locale;

  /// The host's certificate, base64 DER (§2.2). Null means first use — the next connection adopts
  /// what it sees and sets this, and the caller saves it so the one after that can compare.
  String? certificate;

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

  final _status = StreamController<SessionStatus>.broadcast();
  SessionStatus _state = SessionStatus.connecting;

  /// The link's state, replayed to late subscribers so the deck screen never has to guess.
  Stream<SessionStatus> get status async* {
    yield _state;
    yield* _status.stream;
  }

  SessionStatus get currentStatus => _state;

  void _setStatus(SessionStatus s) {
    if (_state == s) return;
    _state = s;
    if (!_status.isClosed) _status.add(s);
  }

  /// The decks this host offers, from the last `hello_ack`. Re-read on every reconnect, so a deck
  /// added in the editor shows up without restarting the app.
  List<DeckSummary> decks = const [];

  /// Mode to restore after a reconnect. A reconnect starts a brand-new session on the host, which
  /// defaults to auto — without this, every dropped connection would silently kick the user out of
  /// the deck they were using.
  String? _manualDeckId;
  bool _wantManual = false;

  Timer? _retry;
  int _attempt = 0;
  bool _closed = false;

  /// The host pings every 15 s (§4.4). Silence for longer than this means the link is gone —
  /// whatever the socket believes.
  ///
  /// `onDone`/`onError` are not enough on their own, and that is not an edge case: a phone that
  /// sleeps, or whose Wi-Fi radio drops into power save, leaves a HALF-OPEN TCP connection. Nothing
  /// errors and nothing closes; frames simply stop arriving and everything sent goes nowhere. The
  /// deck kept saying "online" while every press timed out one at a time, which is exactly what
  /// "no funciona, ni cambiar de página" looked like. Two and a half missed pings, so a single
  /// late one costs nothing. Injectable only so a test does not have to wait forty seconds.
  final Duration silenceLimit;
  Timer? _watchdog;

  /// Restarts the silence timer. Called for EVERY frame, ping included — the point is traffic, not
  /// which message it was.
  void _heardFromHost() {
    if (_closed) return;
    _watchdog?.cancel();
    _watchdog = Timer(silenceLimit, () {
      trace('nothing from the host in ${silenceLimit.inSeconds}s — treating the link as gone');
      _onDisconnected();
    });
  }

  /// Opens the socket and authenticates. Returns the host's display name.
  /// Throws [HelloException] with a short code on any failure, never hangs.
  Future<String> connect() async {
    final name = await _openSocket();
    _setStatus(SessionStatus.online);
    return name;
  }

  Future<String> _openSocket() async {
    _setStatus(SessionStatus.connecting);
    final PinnedSocket pinned;
    try {
      pinned = await PinnedSocket.connect(
        ip,
        port,
        expected: certificate,
        timeout: handshakeTimeout,
      );
    } on TimeoutException {
      throw const HelloException('connect_timeout');
    } catch (e) {
      // A refused certificate lands here too, as a handshake failure. It is deliberately NOT
      // fatal: a host that was reinstalled looks the same from out here, and the reconnect loop
      // retrying is the same thing it does for a PC that is simply off.
      throw HelloException('connect_failed: $e');
    }
    // First use adopts what it saw (§2.2). Every connection after this compares against it, so
    // this is the one moment the value can change.
    certificate ??= pinned.certificate;
    final channel = pinned.channel;
    _channel = channel;
    _socket = channel.stream.listen(
      (raw) {
        _heardFromHost();
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
      // NOTE: neither of these closes `_incoming`. It outlives individual sockets — the deck
      // screen subscribes to it once and must keep its subscription across every reconnect.
      onError: (Object _) => _onDisconnected(),
      onDone: _onDisconnected,
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
      'grid': {'rows': _grid.rows, 'cols': _grid.cols},
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
    // The decks the host offers (§2). This has arrived on every `hello_ack` since F1 and was
    // thrown away until F7 — without it the phone can only reach whichever deck happens to be
    // first in config.json, or one that some other deck has a `deck:` key pointing at.
    decks = ((ack['decks'] as List?) ?? const [])
        .map((d) => DeckSummary.fromJson(d as Map<String, dynamic>))
        .toList(growable: false);
    _heardFromHost(); // the link is live: start expecting pings
    return ack['name'] as String? ?? '';
  }

  /// Starts the retry loop without a successful first connection — for a launch where the host is
  /// simply asleep. The deck opens offline and comes to life when the PC does.
  void reconnectLater() {
    _setStatus(SessionStatus.offline);
    _scheduleReconnect();
  }

  /// The socket went away. Everything below assumes this can happen at ANY moment — a phone on
  /// Wi-Fi is disconnected far more often than it is connected badly.
  void _onDisconnected() {
    if (_closed) return;
    _watchdog?.cancel();
    _watchdog = null;
    _socket?.cancel();
    _socket = null;
    _channel?.sink.close();
    _channel = null;
    _setStatus(SessionStatus.offline);
    _scheduleReconnect();
  }

  /// Exponential backoff capped at 15 s: a host that is simply off should not be hammered, but a
  /// Wi-Fi blip should recover in about a second.
  void _scheduleReconnect() {
    if (_closed || _retry != null) return;
    final delay = Duration(milliseconds: (500 * (1 << _attempt.clamp(0, 5))).clamp(500, 15000));
    _attempt++;
    _retry = Timer(delay, () async {
      _retry = null;
      if (_closed) return;
      try {
        await _openSocket();
        _attempt = 0;
        _setStatus(SessionStatus.online);
        // A reconnect is a NEW session on the host, which starts in auto mode. Put the user back
        // where they were rather than silently switching decks under them.
        if (_wantManual) await setMode('manual', deckId: _manualDeckId);
      } on HelloException catch (e) {
        if (e.isFatal) {
          // The token is dead (revoked from the host UI). Retrying forever would be a loop the
          // app can never win; the screen has to send the user back to pairing.
          _setStatus(SessionStatus.dead);
          return;
        }
        _setStatus(SessionStatus.offline);
        _scheduleReconnect();
      } catch (_) {
        _setStatus(SessionStatus.offline);
        _scheduleReconnect();
      }
    });
  }

  @override
  Stream<Layout> layouts() async* {
    // Replay the current layout so a subscriber that arrives late still has something to draw.
    final cached = _last;
    if (cached != null) yield cached;
    yield* _messages.where((m) => m['type'] == 'layout').map(Layout.fromJson);
  }

  @override
  Stream<Layout> preloads() =>
      // The same body as a `layout`, so the same parser. Deliberately NOT merged into `layouts()`:
      // everything downstream of that stream draws what it is given, and a preload must not.
      _messages.where((m) => m['type'] == 'page_preload').map(Layout.fromJson);

  @override
  Future<void> pressKey({required int pos, required String press}) =>
      pressResult(pos: pos, press: press);

  /// [pressKey] plus the host's answer, for callers that need to assert on it. A navigating key
  /// (folder/page) is answered with the new `layout` instead of a `key_result` — for navigation
  /// the layout IS the result — so waiting for either keeps both cases from hanging. The layout
  /// also reaches the UI through [layouts], which shares this broadcast stream.
  Future<Map<String, dynamic>> pressResult({required int pos, required String press}) async {
    final id = '${++_keyId}';
    final answered = _messages.firstWhere(
      (m) => (m['type'] == 'key_result' && m['id'] == id) || m['type'] == 'layout',
    );
    _send({'v': 2, 'type': 'key', 'id': id, 'page': _page, 'pos': pos, 'press': press});
    // Bounded like every other request: the caller lights the key green on this future, so an
    // unanswered press would otherwise leave it waiting for a confirmation that never comes. This
    // one still THROWS, unlike session control — the caller is waiting on the answer to decide
    // whether to light the key — but a press that went unanswered also means the link is down, and
    // saying so is what starts the reconnect.
    try {
      return await answered.timeout(handshakeTimeout);
    } on TimeoutException {
      trace('no answer to a key press — the link is down');
      _onDisconnected();
      rethrow;
    }
  }

  @override
  Future<void> setMode(String mode, {String? deckId}) async {
    _wantManual = mode == 'manual';
    _manualDeckId = deckId ?? _manualDeckId;
    final replied = _replyTo();
    _send({'v': 2, 'type': 'set_mode', 'mode': mode, 'deckId': ?deckId});
    await _sessionRequest(replied);
  }

  /// Protocol §4.4 `set_grid` — the phone was rotated, so the grid it derived from the screen
  /// changed. No-ops when the grid is unchanged: this is called from a layout builder, which runs
  /// on every frame.
  Future<void> setGrid(Grid next) async {
    if (next.rows == _grid.rows && next.cols == _grid.cols) return;
    _grid = next;
    final replied = _replyTo();
    _send({
      'v': 2,
      'type': 'set_grid',
      'grid': {'rows': next.rows, 'cols': next.cols},
    });
    await _sessionRequest(replied);
  }

  /// Protocol §4.4 `set_page` — swiping between the pages of a deck.
  Future<void> setPage(int page) async {
    final replied = _replyTo();
    _send({'v': 2, 'type': 'set_page', 'page': page});
    await _sessionRequest(replied);
  }

  /// Subscribes for a session-control reply before the request goes out. Both `set_mode` and
  /// `set_page` are answered with the resulting `layout`, or a `command_result` when there is
  /// nothing to render.
  Future<Map<String, dynamic>> _replyTo() =>
      _messages.firstWhere((m) => m['type'] == 'layout' || m['type'] == 'command_result');

  /// Waits for a session-control reply, and treats not getting one as what it is: the link is not
  /// working. Two things follow from that, and both were missing.
  ///
  /// It marks the link down, so the banner says so and the reconnect starts — otherwise a
  /// half-open socket is only ever discovered one failed request at a time, and never repaired.
  ///
  /// And it does NOT rethrow. `set_mode`, `set_page` and `set_grid` are called from taps, gestures
  /// and a layout builder, none of which catch: the mode toggle surfaced an 8-second
  /// `TimeoutException` as an unhandled error in the widget tree while the user just saw a button
  /// that did nothing. The banner is where this belongs.
  Future<void> _sessionRequest(Future<Map<String, dynamic>> reply) async {
    try {
      await reply.timeout(handshakeTimeout);
    } on TimeoutException {
      trace('no answer to a session request — the link is down');
      _onDisconnected();
    }
  }

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

  /// Drops the message when there is no socket. A key press while the link is down must not throw
  /// into the widget tree — the caller's timeout reports it, and the reconnect is already running.
  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> dispose() async {
    _closed = true; // stops the reconnect loop: an intentional close is not a dropped connection
    _watchdog?.cancel();
    _watchdog = null;
    _retry?.cancel();
    _retry = null;
    await _socket?.cancel();
    _socket = null;
    if (!_incoming.isClosed) await _incoming.close();
    if (!_status.isClosed) await _status.close();
    await _channel?.sink.close();
    _channel = null;
  }
}
