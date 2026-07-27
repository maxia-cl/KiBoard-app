import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

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
  WebSocketChannel? _channel;
  Stream<Map<String, dynamic>>? _messages;

  Future<void> connect(String ip, int port) async {
    final channel = WebSocketChannel.connect(Uri.parse('ws://$ip:$port'));
    await channel.ready;
    _channel = channel;
    _messages = channel.stream
        .map((raw) => jsonDecode(raw as String) as Map<String, dynamic>)
        .asBroadcastStream();
  }

  /// Sends `pair_request` and waits for the host to show a code on its screen. Returns how many
  /// seconds the code is valid for.
  @override
  Future<int> requestCode({required String device, required String platform}) async {
    _send({'v': 2, 'type': 'pair_request', 'device': device, 'platform': platform});
    final msg = await _messages!.firstWhere((m) => m['type'] == 'pair_challenge' || m['type'] == 'pair_ack');
    if (msg['type'] == 'pair_ack') {
      throw PairingException(msg['error'] as String? ?? 'pairing_closed');
    }
    return msg['expiresIn'] as int? ?? 120;
  }

  /// Sends the code the user typed (or scanned). Throws [PairingException] on a wrong/expired
  /// code or a lockout; returns the device's own token on success.
  @override
  Future<PairingResult> confirmCode(String code) async {
    _send({'v': 2, 'type': 'pair_confirm', 'code': code});
    final msg = await _messages!.firstWhere((m) => m['type'] == 'pair_ack');
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
    await _channel?.sink.close();
  }
}
