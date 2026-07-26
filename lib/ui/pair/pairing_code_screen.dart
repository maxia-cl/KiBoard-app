import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../mock/mock_discovery.dart';
import '../../mock/mock_layout_source.dart';
import '../deck/deck_screen.dart';
import '../tokens.g.dart';

/// protocol/README.md §2: six-digit code shown on the PC, typed on the phone. FP has no real PC
/// screen to show it on, so any 6-digit code "succeeds" — the flow and the friction are what's
/// under test, not code validation (that's the host's job in F1).
class PairingCodeScreen extends StatefulWidget {
  final DiscoveredHost host;
  final MockDiscovery discovery;
  const PairingCodeScreen({super.key, required this.host, required this.discovery});

  @override
  State<PairingCodeScreen> createState() => _PairingCodeScreenState();
}

class _PairingCodeScreenState extends State<PairingCodeScreen> {
  final _controller = TextEditingController();
  bool _checking = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await widget.discovery.confirmCode(_controller.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DeckScreen(layoutSource: MockLayoutSource(), hostName: widget.host.name),
        ),
      );
    } else {
      setState(() {
        _checking = false;
        _error = 'Enter the 6-digit code shown on the PC';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
            TextField(
              controller: _controller,
              autofocus: true,
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
                onPressed: _checking || _controller.text.length != 6 ? null : _confirm,
                child: _checking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
