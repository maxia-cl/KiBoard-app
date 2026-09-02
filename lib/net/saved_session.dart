import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Everything needed to re-open a session without pairing again (protocol §2: the token is
/// per-device and survives restarts — pairing is a one-time physical act at the PC, so asking for
/// a six-digit code on every launch would be a bug, not security).
///
/// The token is a bearer credential for the LAN. It lives in SharedPreferences, which on Android
/// is private to the app's sandbox. Since F7 it no longer crosses the network in the clear — the
/// Keystore is still the right home for it, and still not where it lives.
class SavedSession {
  final String ip;
  final int port;
  final String token;
  final String deviceId;
  final String hostName;

  /// Stable mDNS identity of the paired PC. The IP is only a DHCP lease and can change whenever
  /// the router or PC restarts; this is what lets the phone find the same host again without
  /// pairing a second time. Empty for sessions stored before this field existed.
  final String hostId;

  /// The host's certificate, base64 DER — pinned at pairing (§2.2). Null on a session stored
  /// before pinning existed: the next connection adopts what it sees and saves it, which is
  /// first-use trust and is written down as such in the contract.
  final String? certificate;

  const SavedSession({
    required this.ip,
    required this.port,
    required this.token,
    required this.deviceId,
    required this.hostName,
    this.hostId = '',
    this.certificate,
  });

  SavedSession copyWith({
    String? ip,
    int? port,
    String? hostName,
    String? hostId,
    String? certificate,
  }) => SavedSession(
    ip: ip ?? this.ip,
    port: port ?? this.port,
    token: token,
    deviceId: deviceId,
    hostName: hostName ?? this.hostName,
    hostId: hostId ?? this.hostId,
    certificate: certificate ?? this.certificate,
  );

  SavedSession withCertificate(String cert) => copyWith(certificate: cert);

  static const _key = 'session';

  Map<String, dynamic> toJson() => {
    'ip': ip,
    'port': port,
    'token': token,
    'deviceId': deviceId,
    'hostName': hostName,
    'hostId': hostId,
    'certificate': ?certificate,
  };

  static SavedSession _fromJson(Map<String, dynamic> j) => SavedSession(
    ip: j['ip'] as String,
    port: j['port'] as int,
    token: j['token'] as String,
    deviceId: j['deviceId'] as String,
    hostName: j['hostName'] as String? ?? '',
    hostId: j['hostId'] as String? ?? '',
    certificate: j['certificate'] as String?,
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
