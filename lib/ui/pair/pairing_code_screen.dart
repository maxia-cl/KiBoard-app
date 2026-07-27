import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../net/discovered_host.dart';
import '../../net/layout_source.dart';
import '../../net/pairing_client.dart';
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
  final PairingClient? _realClient;
  final Pairing? _injectedClient;

  /// Injectable so widget tests can reach the deck screen without a live host. Null = the real
  /// [WsLayoutSource] session.
  final Future<LayoutSource> Function(PairingResult)? openSession;

  /// Real usage: opens a fresh [PairingClient] connected to [host].
  PairingCodeScreen({super.key, required this.host})
    : _realClient = PairingClient(),
      _injectedClient = null,
      openSession = null;

  /// Test-only: skips the real connect() step and drives an already-configured fake.
  const PairingCodeScreen.withClient({
    super.key,
    required this.host,
    required Pairing client,
    this.openSession,
  }) : _realClient = null,
       _injectedClient = client;

  Pairing get _client => _injectedClient ?? _realClient!;

  @override
  State<PairingCodeScreen> createState() => _PairingCodeScreenState();
}

class _PairingCodeScreenState extends State<PairingCodeScreen> {
  final _controller = TextEditingController();
  bool _checking = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startPairing();
  }

  Future<void> _startPairing() async {
    try {
      final client = widget._client;
      if (client is PairingClient) {
        await client.connect(widget.host.ip, widget.host.port);
      }
      await widget._client.requestCode(device: 'KiBoard phone', platform: 'android');
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is PairingException ? (_errorMessages[e.code] ?? e.code) : 'Could not reach that PC.');
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result = await widget._client.confirmCode(_controller.text);
      final source = await (widget.openSession ?? _openRealSession)(result);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DeckScreen(layoutSource: source, hostName: result.hostName),
        ),
      );
    } on PairingException catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = _errorMessages[e.code] ?? e.code;
      });
    } catch (e) {
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
    final source = WsLayoutSource(
      ip: widget.host.ip,
      port: widget.host.port,
      token: result.token,
      deviceId: result.deviceId,
    );
    await source.connect();
    // Manual mode on entry: auto mode still serves v1's Profile/Button layout, which this screen
    // cannot render. F3 is what moves auto mode onto the Deck/Page/Key shape.
    await source.setMode('manual');
    return source;
  }

  @override
  void dispose() {
    _controller.dispose();
    widget._client.dispose();
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
