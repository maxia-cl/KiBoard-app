import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../net/discovered_host.dart';
import '../../net/layout_source.dart';
import '../../net/pairing_client.dart';
import '../../net/saved_session.dart';
import '../../net/trace.dart';
import '../../net/ws_layout_source.dart';
import '../deck/deck_screen.dart';
import '../tokens.g.dart';

const _errorMessages = {
  'pairing_closed': "This PC isn't accepting new pairings right now.",
  'bad_code': 'Wrong code — check the PC screen and try again.',
  'rate_limited': 'Too many wrong attempts. Wait a few minutes and try again.',
};

/// protocol/README.md §2: a real pair_request/pair_challenge/pair_confirm/pair_ack round trip
/// over a fresh WebSocket to the discovered host. On success it opens a SECOND connection — the
/// authenticated session ([WsLayoutSource], §4) — and hands it to the deck screen.
class PairingCodeScreen extends StatefulWidget {
  final DiscoveredHost host;

  /// Test-only injected client. Null in real use, where the State owns a real [PairingClient] and
  /// can REPLACE it: a socket that dies mid-pairing is unrecoverable, so starting over means a new
  /// client, which is why ownership cannot live on this immutable widget.
  final Pairing? injectedClient;

  /// Injectable so widget tests can reach the deck screen without a live host. Null = the real
  /// [WsLayoutSource] session.
  final Future<LayoutSource> Function(PairingResult)? openSession;

  const PairingCodeScreen({super.key, required this.host})
    : injectedClient = null,
      openSession = null;

  /// Test-only: skips the real connect() step and drives an already-configured fake.
  const PairingCodeScreen.withClient({
    super.key,
    required this.host,
    required Pairing client,
    this.openSession,
  }) : injectedClient = client;

  @override
  State<PairingCodeScreen> createState() => _PairingCodeScreenState();
}

class _PairingCodeScreenState extends State<PairingCodeScreen> {
  final _controller = TextEditingController();
  bool _checking = false;
  bool _ready = false;
  bool _paired = false;
  String? _error;
  late Pairing _client = widget.injectedClient ?? PairingClient();

  /// Kept so the deck screen can show the link state. Null when a test injects its own source.
  WsLayoutSource? _session;

  @override
  void initState() {
    super.initState();
    _startPairing();
  }

  Future<void> _startPairing() async {
    try {
      final client = _client;
      if (client is PairingClient) {
        trace('pairing connect -> ${widget.host.ip}:${widget.host.port}');
        await client.connect(widget.host.ip, widget.host.port);
        trace('pairing socket open');
      }
      await _client.requestCode(device: 'KiBoard phone', platform: 'android');
      trace('pair_challenge received, waiting for the user to type the code');
      if (!mounted) return;
      setState(() => _ready = true);
      _watchForDeadSocket();
    } catch (e) {
      trace('pairing setup FAILED: $e');
      if (!mounted) return;
      setState(() => _error = e is PairingException ? (_errorMessages[e.code] ?? e.code) : 'Could not reach that PC.');
    }
  }

  /// The socket can die while the user is still reading the code off the PC. Rather than let
  /// Confirm fail against a dead connection, start over: a fresh socket means a fresh code, so the
  /// user is told to look at the PC again instead of retyping digits that can no longer work.
  void _watchForDeadSocket() {
    final client = _client;
    if (client is! PairingClient) return; // injected fakes have no socket to lose
    client.died.then((_) {
      if (!mounted || _paired) return;
      trace('pairing socket died while waiting for the code — requesting a new one');
      setState(() {
        _ready = false;
        _checking = false;
        _controller.clear();
        _error = 'The connection dropped. Getting a new code — check the PC screen.';
      });
      // A dead socket is unrecoverable, and the code it issued died with it: start clean.
      _client = PairingClient();
      _startPairing();
    });
  }

  Future<void> _confirm() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      trace('pair_confirm sent');
      final result = await _client.confirmCode(_controller.text);
      _paired = true; // stops the dead-socket watcher from restarting pairing under our feet
      trace('pair_ack ok, deviceId=${result.deviceId}');
      final source = await (widget.openSession ?? _openRealSession)(result);
      trace('session ready, opening the deck');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DeckScreen(
            layoutSource: source,
            hostName: result.hostName,
            session: _session,
          ),
        ),
      );
    } on PairingException catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = _errorMessages[e.code] ?? e.code;
      });
    } catch (e) {
      trace('session FAILED: $e');
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Paired, but the session could not start: $e';
      });
    }
  }

  /// The authenticated session. Pairing and the session are deliberately separate connections:
  /// pairing is unauthenticated by definition, the session carries the token.
  Future<LayoutSource> _openRealSession(PairingResult result) async {
    // The pairing socket has done its job; holding it open would leave the host with two
    // connections per phone for the rest of the session.
    await _client.dispose();
    trace('pairing socket closed; opening session -> ${widget.host.ip}:${widget.host.port}');
    final source = WsLayoutSource(
      ip: widget.host.ip,
      port: widget.host.port,
      token: result.token,
      deviceId: result.deviceId,
    );
    final hostName = await source.connect();
    trace('hello_ack ok');
    // Stays in AUTO mode, the host's default and the product's whole point: the keys follow the
    // foreground app with nothing to configure. F2 moved auto onto the Deck/Page/Key shape, so
    // there is no longer any reason to force manual here.
    _session = source;
    await SavedSession(
      ip: widget.host.ip,
      port: widget.host.port,
      token: result.token,
      deviceId: result.deviceId,
      hostName: hostName.isEmpty ? result.hostName : hostName,
    ).save();
    trace('session saved — next launch skips pairing');
    return source;
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: const Color(DeckTokens.textPrimary)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${widget.host.name}" wants to connect',
              style: const TextStyle(color: Color(DeckTokens.textPrimary), fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the 6-digit code shown on that PC. It expires in 120 s.',
              style: TextStyle(color: Color(DeckTokens.textSecondary)),
            ),
            const SizedBox(height: 24),
            if (!_ready && _error == null)
              const Center(child: CircularProgressIndicator(color: Color(DeckTokens.accent)))
            else ...[
              TextField(
                controller: _controller,
                autofocus: true,
                enabled: _ready,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                maxLength: 6,
                onChanged: (_) => setState(() {}),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(DeckTokens.textPrimary), fontSize: 32, letterSpacing: 12),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFF1E1E20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(DeckTokens.accent), padding: const EdgeInsets.all(14)),
                  onPressed: !_ready || _checking || _controller.text.length != 6 ? null : _confirm,
                  child: _checking
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirm'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
