import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Everything needed to re-open a session without pairing again (protocol §2: the token is
/// per-device and survives restarts — pairing is a one-time physical act at the PC, so asking for
/// a six-digit code on every launch would be a bug, not security).
///
/// The token is a bearer credential for the LAN. It lives in SharedPreferences, which on Android
/// is private to the app's sandbox — good enough while the transport is plain `ws://` anyway.
/// F7's `wss://` work is when this deserves the Keystore.
class SavedSession {
  final String ip;
  final int port;
  final String token;
  final String deviceId;
  final String hostName;

  const SavedSession({
    required this.ip,
    required this.port,
    required this.token,
    required this.deviceId,
    required this.hostName,
  });

  static const _key = 'session';

  Map<String, dynamic> toJson() => {
    'ip': ip,
    'port': port,
    'token': token,
    'deviceId': deviceId,
    'hostName': hostName,
  };

  static SavedSession _fromJson(Map<String, dynamic> j) => SavedSession(
    ip: j['ip'] as String,
    port: j['port'] as int,
    token: j['token'] as String,
    deviceId: j['deviceId'] as String,
    hostName: j['hostName'] as String? ?? '',
  );

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  /// The stored session, or null if there is none (or it is unreadable — a corrupt entry must send
  /// the user to pairing, never crash the launch).
  static Future<SavedSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return _fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return null;
    }
  }

  /// Called when the host says `revoked` or `invalid_token`: the credential is dead, so keeping it
  /// would trap the app in a reconnect loop it can never win.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
