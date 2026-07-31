import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

import 'discovered_host.dart';
import 'trace.dart';

/// A `wss://` connection that trusts exactly ONE certificate (protocol §2.2).
///
/// The host is self-signed — a LAN has no certificate authority to appeal to — so ordinary
/// validation would refuse every connection, and turning validation off would trust anything that
/// answers on that address. Pinning is the middle: whatever was seen at pairing, and nothing else.
///
/// The whole DER is compared rather than a hash of it. That is strictly stronger, it is ~350 bytes
/// in the saved session, and it means the app needs no crypto library to do the one comparison it
/// makes.
class PinnedSocket {
  /// The certificate this connection actually presented, base64 DER — what to store after a
  /// first-use connection, and what to compare on every one after that.
  final String certificate;
  final IOWebSocketChannel channel;

  const PinnedSocket._(this.certificate, this.channel);

  /// Opens a connection to [host]:[port].
  ///
  /// [expected] is the certificate from the saved session. When it is null this is first use —
  /// pairing, or a session stored before pinning existed — and whatever the host presents is
  /// adopted and handed back to be saved. When it is set, anything else is refused: the handshake
  /// fails and the caller sees a dead connection, which is the correct outcome for a host that is
  /// not the one it claims to be.
  static Future<PinnedSocket> connect(
    String host,
    int port, {
    String? expected,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    String? seen;
    final client = HttpClient()
      ..badCertificateCallback = (cert, _, _) {
        seen = base64Encode(cert.der);
        if (expected == null) return true; // first use: adopt it
        final ok = seen == expected;
        if (!ok) {
          trace('certificate for $host is not the pinned one — refusing');
        }
        return ok;
      };

    try {
      final channel = IOWebSocketChannel.connect(
        wssUri(host, port),
        customClient: client,
        connectTimeout: timeout,
      );
      await channel.ready.timeout(timeout);
      // `badCertificateCallback` only fires for a certificate that failed ordinary validation,
      // which a self-signed one always does — so by here it has run and `seen` is set.
      return PinnedSocket._(seen ?? '', channel);
    } finally {
      // The client owns the connection until the socket takes over; closing it here would kill a
      // live channel, so it is only closed on the failure path.
      if (seen == null) client.close(force: true);
    }
  }
}
