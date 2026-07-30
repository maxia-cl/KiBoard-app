import 'package:flutter/material.dart';

import '../../net/discovered_host.dart';
import '../../net/discovery.dart';
import '../../net/mdns_discovery.dart';
import '../tokens.g.dart';
import 'pairing_code_screen.dart';

/// protocol/README.md §1: the phone browses `_kiboard._tcp` and lists hosts without scanning
/// anything, and R1's fallback lives here too — typing the address by hand, for the networks that
/// block multicast. Discovery is a convenience, never the only way in.
class DiscoverScreen extends StatefulWidget {
  final Discovery discovery;
  DiscoverScreen({super.key, Discovery? discovery}) : discovery = discovery ?? MdnsDiscovery();

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late Future<List<DiscoveredHost>> _hosts = widget.discovery.discover();

  void _rescan() {
    setState(() => _hosts = widget.discovery.discover());
  }

  void _open(DiscoveredHost host) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PairingCodeScreen(host: host)));
  }

  /// R1's escape hatch: the address typed by hand. Deliberately reuses the ordinary pairing screen
  /// — a typed host is still a §2 pair_request, so there is no second flow to keep working.
  Future<void> _enterAddress() async {
    // No TextEditingController on purpose: the sheet keeps animating out after `pop`, so anything
    // disposed when this function resumes is still being built for a few frames. `onChanged` into a
    // local has no lifecycle to get wrong.
    var text = '';
    String? error;
    final typed = await showModalBottomSheet<({String host, int port})>(
      context: context,
      isScrollControlled: true, // the keyboard is what makes this sheet tight
      backgroundColor: const Color(0xFF1E1E20),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void submit() {
            final parsed = parseHostAddress(text);
            if (parsed == null) {
              setSheetState(() => error = "That doesn't look like an address.");
              return;
            }
            Navigator.of(sheetContext).pop(parsed);
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(sheetContext).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Your PC's address",
                  style: TextStyle(color: Color(DeckTokens.textPrimary), fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'KiBoard shows it on the PC, under the pairing code. The port is '
                  '$defaultHostPort unless you changed it.',
                  style: TextStyle(color: Color(DeckTokens.textSecondary), fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  autofocus: true,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onChanged: (v) => text = v,
                  onSubmitted: (_) => submit(),
                  style: const TextStyle(color: Color(DeckTokens.textPrimary)),
                  decoration: InputDecoration(
                    hintText: '192.168.1.11',
                    hintStyle: const TextStyle(color: Color(DeckTokens.textSecondary)),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(DeckTokens.accent),
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: submit,
                    child: const Text('Connect'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (typed == null || !mounted) return;
    _open(DiscoveredHost.typed(host: typed.host, port: typed.port));
  }

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
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator(color: Color(DeckTokens.accent)));
                    }
                    final hosts = snapshot.data ?? const [];
                    if (hosts.isEmpty) {
                      // R1: a discovery failure must be EXPLAINED, not left blank. The two causes
                      // that actually happen are a network that drops multicast and a firewall
                      // that has not been allowed yet, and neither is the user's fault or fixable
                      // from this screen — so the way out is offered right here.
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'No PCs found on this network yet.',
                              style: TextStyle(color: Color(DeckTokens.textPrimary), fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Some networks never pass on the messages KiBoard listens for — '
                              'guest WiFi and plenty of ISP routers among them. The PC can also '
                              'still be waiting for you to allow it through its firewall.\n\n'
                              'Typing the address works on any network.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(DeckTokens.textSecondary), fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(onPressed: _rescan, child: const Text('Scan again')),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: const Color(DeckTokens.accent)),
                                  onPressed: _enterAddress,
                                  child: const Text('Enter its address'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
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
                            onTap: () => _open(host),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.desktop_windows, color: Color(DeckTokens.accent)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          host.name,
                                          style: const TextStyle(
                                            color: Color(DeckTokens.textPrimary),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (!host.pairingOpen)
                                          const Text(
                                            'Not accepting new pairings right now',
                                            style: TextStyle(color: Color(DeckTokens.textSecondary), fontSize: 12),
                                          ),
                                      ],
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
                  onPressed: _enterAddress,
                  icon: const Icon(Icons.keyboard_alt_outlined, color: Color(DeckTokens.textSecondary)),
                  label: const Text(
                    "Don't see your PC? Enter its address",
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
