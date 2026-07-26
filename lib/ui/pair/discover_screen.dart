import 'package:flutter/material.dart';

import '../../mock/mock_discovery.dart';
import '../tokens.g.dart';
import 'pairing_code_screen.dart';

/// protocol/README.md §1: the phone browses `_kiboard._tcp` and lists hosts without scanning
/// anything. QR / manual IP stay as the mandatory fallback (R1) even though FP fakes discovery.
class DiscoverScreen extends StatefulWidget {
  final MockDiscovery discovery;
  const DiscoverScreen({super.key, required this.discovery});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late final Future<List<DiscoveredHost>> _hosts = widget.discovery.discover();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KiBoard',
                style: TextStyle(color: Color(DeckTokens.textPrimary), fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('Looking for PCs on your network…', style: TextStyle(color: Color(DeckTokens.textSecondary))),
              const SizedBox(height: 24),
              Expanded(
                child: FutureBuilder<List<DiscoveredHost>>(
                  future: _hosts,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(DeckTokens.accent)));
                    }
                    final hosts = snapshot.data!;
                    return ListView.separated(
                      itemCount: hosts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final host = hosts[i];
                        return Material(
                          color: const Color(0xFF1E1E20),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => PairingCodeScreen(host: host, discovery: widget.discovery)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.desktop_windows, color: Color(DeckTokens.accent)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      host.name,
                                      style: const TextStyle(color: Color(DeckTokens.textPrimary), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Color(DeckTokens.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.qr_code, color: Color(DeckTokens.textSecondary)),
                  label: const Text(
                    "Don't see your PC? Scan a QR or enter its address",
                    style: TextStyle(color: Color(DeckTokens.textSecondary)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
