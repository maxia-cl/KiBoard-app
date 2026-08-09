import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

import 'discovered_host.dart';
import 'trace.dart';

/// The host served a certificate that is not the pinned one (protocol §2.2).
///
/// Deliberately NOT fatal — the saved session is kept and the app keeps retrying. Clearing it
/// automatically is precisely what somebody standing in the middle would want: refuse once, and
/// the phone helpfully forgets the identity it was protecting. Only the user gets to decide, from
/// "Forget this PC" in Settings. What this exception buys is the UI being able to SAY so, instead
/// of showing the same "the PC is asleep" copy for a state that waiting cannot fix.
class CertificateChanged implements Exception {
  const CertificateChanged();
  @override
  String toString() => 'certificate_changed';
}

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
    var mismatch = false;
    var handedOver = false;
    final client = HttpClient()
      ..badCertificateCallback = (cert, _, _) {
        seen = base64Encode(cert.der);
        if (expected == null) return true; // first use: adopt it
        final ok = seen == expected;
        if (!ok) {
          mismatch = true;
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
      handedOver = true;
      return PinnedSocket._(seen ?? '', channel);
    } on Object {
      // A refusal arrives as an ordinary handshake failure, which is indistinguishable from a PC
      // that is simply off. Naming it is what lets the UI say "pair again" for the one case where
      // waiting cannot help.
      if (mismatch) throw const CertificateChanged();
      rethrow;
    } finally {
      // The client owns the connection until the socket takes over; closing it here would kill a
      // live channel, so it is only closed when no socket was handed out. `seen` is set on the
      // refusal path too, so it cannot be the test.
      if (!handedOver) client.close(force: true);
    }
  }
}
