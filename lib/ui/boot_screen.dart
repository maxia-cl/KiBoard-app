import 'package:flutter/material.dart';

import '../net/saved_session.dart';
import '../net/trace.dart';
import '../net/ws_layout_source.dart';
import 'deck/deck_screen.dart';
import 'pair/discover_screen.dart';
import 'tokens.g.dart';

/// Decides what the app opens on: the deck if this phone is already paired, discovery if not.
///
/// Pairing is a one-time physical act at the PC (protocol §2) and the token is per-device and
/// durable, so asking for a six-digit code on every launch would be a bug. If the reconnect fails
/// the deck screen shows it and keeps retrying — being offline is not a reason to un-pair.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  late final Future<Widget> _next = _decide();

  Future<Widget> _decide() async {
    final saved = await SavedSession.load();
    if (saved == null) {
      trace('no saved session — going to discovery');
      return DiscoverScreen();
    }
    trace('saved session for ${saved.ip}:${saved.port} — reconnecting');
    final source = WsLayoutSource(
      ip: saved.ip,
      port: saved.port,
      token: saved.token,
      deviceId: saved.deviceId,
    );
    try {
      await source.connect();
      trace('reconnected to "${saved.hostName}"');
    } on HelloException catch (e) {
      // A revoked token is the one case where the saved session is worthless: drop it and pair
      // again. Anything else is a host that is merely asleep — open the deck and let it retry.
      if (e.isFatal) {
        trace('saved session rejected ($e) — clearing it');
        await SavedSession.clear();
        await source.dispose();
        return DiscoverScreen();
      }
      trace('host unreachable ($e) — opening the deck offline, it will keep retrying');
      source.reconnectLater();
    }
    return DeckScreen(layoutSource: source, hostName: saved.hostName, session: source);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _next,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0F10),
            body: Center(child: CircularProgressIndicator(color: Color(DeckTokens.accent))),
          );
        }
        return snapshot.data!;
      },
    );
  }
}
