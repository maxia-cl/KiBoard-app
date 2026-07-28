import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'discovered_host.dart';

/// Thrown for every `error` code the host can send back during pairing (protocol/README.md §5):
/// pairing_closed, bad_code, rate_limited, protocol_too_old...
class PairingException implements Exception {
  final String code;
  const PairingException(this.code);
  @override
  String toString() => code;
}

class PairingResult {
  final String token;
  final String deviceId;
  final String hostName;
  const PairingResult({required this.token, required this.deviceId, required this.hostName});
}

/// Seam so tests can inject a fake instead of opening a real socket. [PairingClient] is the only
/// real implementation.
abstract class Pairing {
  Future<int> requestCode({required String device, required String platform});
  Future<PairingResult> confirmCode(String code);
  Future<void> dispose();
}

/// Real six-digit-code pairing (protocol/README.md §2) over a fresh WebSocket connection to a
/// host found via [MdnsDiscovery]. One instance is good for one pairing attempt. Callers must
/// [connect] before requesting a code — that step isn't part of the [Pairing] interface because
/// the host/port aren't known until a [DiscoveredHost] is picked.
class PairingClient implements Pairing {
  /// A LAN round trip is milliseconds. Anything near this is a dead socket, and without a bound
  /// the UI spins forever: a half-open TCP connection never completes and never throws.
  static const _timeout = Duration(seconds: 8);

  WebSocketChannel? _channel;

  /// Owned subscription to the socket, created once and cancelled only in [dispose]. Not
  /// `asBroadcastStream()`, whose subscription lifetime is tied to whoever happens to be listening.
  StreamSubscription<dynamic>? _socket;
  final _incoming = StreamController<Map<String, dynamic>>.broadcast();
  final _died = Completer<void>();
  bool _disposed = false;

  /// Completes if the socket dies on its own, before [dispose].
  ///
  /// Between `pair_challenge` and `pair_confirm` sits a human reading six digits off a PC screen:
  /// 20+ seconds of an idle socket, which measurably does NOT always survive on Android. Confirming
  /// into the corpse fails in 3 ms with "Bad state: No element", so the screen has to notice and
  /// fetch a fresh code rather than let the user retype into a dead connection.
  Future<void> get died => _died.future;

  Future<void> connect(String ip, int port) async {
    final channel = WebSocketChannel.connect(wsUri(ip, port));
    await channel.ready.timeout(_timeout);
    _channel = channel;
    _socket = channel.stream.listen(
      (raw) => _incoming.add(jsonDecode(raw as String) as Map<String, dynamic>),
      onError: (Object e) {
        if (!_incoming.isClosed) _incoming.addError(e);
        _noteDeath();
      },
      onDone: _noteDeath,
    );
  }

  void _noteDeath() {
    if (!_incoming.isClosed) _incoming.close();
    if (!_disposed && !_died.isCompleted) _died.complete();
  }

  /// Sends `pair_request` and waits for the host to show a code on its screen. Returns how many
  /// seconds the code is valid for.
  @override
  Future<int> requestCode({required String device, required String platform}) async {
    // Subscribe before sending: on a LAN the reply can land in the same event-loop turn, and a
    // broadcast stream drops whatever arrives while it has no listener.
    final replied = _incoming.stream.firstWhere(
      (m) => m['type'] == 'pair_challenge' || m['type'] == 'pair_ack',
    );
    _send({'v': 2, 'type': 'pair_request', 'device': device, 'platform': platform});
    final msg = await replied.timeout(_timeout);
    if (msg['type'] == 'pair_ack') {
      throw PairingException(msg['error'] as String? ?? 'pairing_closed');
    }
    return msg['expiresIn'] as int? ?? 120;
  }

  /// Sends the code the user typed (or scanned). Throws [PairingException] on a wrong/expired
  /// code or a lockout; returns the device's own token on success.
  @override
  Future<PairingResult> confirmCode(String code) async {
    final acked = _incoming.stream.firstWhere((m) => m['type'] == 'pair_ack');
    _send({'v': 2, 'type': 'pair_confirm', 'code': code});
    // The host deliberately delays every pair_confirm by 500 ms as a brute-force brake, so this
    // bound has to sit well above that.
    final msg = await acked.timeout(_timeout);
    if (msg['ok'] != true) {
      throw PairingException(msg['error'] as String? ?? 'bad_code');
    }
    return PairingResult(
      token: msg['token'] as String,
      deviceId: msg['deviceId'] as String,
      hostName: msg['name'] as String? ?? '',
    );
  }

  void _send(Map<String, dynamic> message) {
    _channel!.sink.add(jsonEncode(message));
  }

  @override
  Future<void> dispose() async {
    _disposed = true; // an intentional close is not a death: `died` must not fire
    await _socket?.cancel();
    _socket = null;
    if (!_incoming.isClosed) await _incoming.close();
    await _channel?.sink.close();
    _channel = null;
  }
}
