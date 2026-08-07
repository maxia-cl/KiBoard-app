import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import '../wordmark.dart';

import '../../net/discovered_host.dart';
import '../../net/discovery.dart';
import '../../net/mdns_discovery.dart';
import '../manual_screen.dart';
import '../nav.dart';
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
    Navigator.of(context).push(screenRoute(PairingCodeScreen(host: host)));
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
          final t = AppLocalizations.of(sheetContext)!;
          void submit() {
            final parsed = parseHostAddress(text);
            if (parsed == null) {
              setSheetState(() => error = t.notAnAddress);
              return;
            }
            Navigator.of(sheetContext).pop(parsed);
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.yourPcsAddress,
                  style: TextStyle(
                    color: Color(DeckTokens.textPrimary),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.addressHint,
                  style: const TextStyle(color: Color(DeckTokens.textSecondary), fontSize: 13),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
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
                    child: Text(t.connect),
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
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The same lockup as the start screen, at header size — KiMouse puts it in exactly
              // these two places, which is what stops the name being a bold word in one and a
              // drawn mark in the other.
              const Wordmark(markHeight: 34),
              const SizedBox(height: 4),
              Text(t.lookingForPcs, style: TextStyle(color: Color(DeckTokens.textSecondary))),
              const SizedBox(height: 24),
              Expanded(
                child: FutureBuilder<List<DiscoveredHost>>(
                  future: _hosts,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(DeckTokens.accent)),
                      );
                    }
                    final hosts = snapshot.data ?? const [];
                    if (hosts.isEmpty) {
                      // R1: a discovery failure must be EXPLAINED, not left blank. The cause that
                      // actually happens is a network that drops multicast, which is neither the
                      // user's fault nor fixable from this screen — so the way out is offered
                      // right here.
                      //
                      // Centred when there is room, scrolling when there is not. A plain `Center`
                      // overflowed the bottom held sideways; a plain scroll view left it stuck to
                      // the top with a void underneath in portrait. `minHeight` is what lets one
                      // widget do both. Of all the screens to get this wrong, the one a user
                      // reaches when nothing else works is the worst.
                      return LayoutBuilder(
                        builder: (context, box) => SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: box.maxHeight),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  t.noPcsFound,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(DeckTokens.textPrimary),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // The host check comes FIRST. The screen used to open with the
                                // multicast explanation, which is true for the networks that hit
                                // it — but somebody who found the phone app before the PC one has
                                // nothing running to be found, and every route offered here was a
                                // dead end for them: rescanning finds nothing and a typed address
                                // connects to nothing.
                                Text(
                                  t.isKiboardRunning,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(DeckTokens.textPrimary),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Two lines, not four. The long version fitted upright and had to
                                // be scrolled sideways, which left the buttons sliced in half
                                // below the fold — it looked broken even though nothing was.
                                Text(
                                  t.noPcsWhy,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(DeckTokens.textSecondary),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Wrap, not Row: two buttons side by side is a nice-to-have, and
                                // at a large text size they simply do not fit next to each other.
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    TextButton(onPressed: _rescan, child: Text(t.scanAgain)),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(DeckTokens.accent),
                                      ),
                                      onPressed: _enterAddress,
                                      child: Text(t.enterAddress),
                                    ),
                                    // The manual answers this screen's question better than this
                                    // screen can, and it was three levels away behind a cog
                                    // nobody stuck here has ever opened.
                                    TextButton(
                                      onPressed: () => Navigator.of(
                                        context,
                                      ).push(screenRoute<void>(const ManualScreen())),
                                      child: Text(t.readTheManual),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
                                  const Icon(
                                    Icons.desktop_windows,
                                    color: Color(DeckTokens.accent),
                                  ),
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
                                          Text(
                                            t.pairingClosed,
                                            style: TextStyle(
                                              color: Color(DeckTokens.textSecondary),
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Color(DeckTokens.textSecondary),
                                  ),
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
              // `TextButton.icon` lays its icon and label out in a Row that never wraps, so a
              // `Center` around it — which hands down loose constraints — let this line run 149 px
              // off the right edge of a 360 px phone. A full-width box gives that Row something to
              // wrap inside, and the button centres its own content.
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _enterAddress,
                  icon: const Icon(
                    Icons.keyboard_alt_outlined,
                    color: Color(DeckTokens.textSecondary),
                    size: 18,
                  ),
                  label: Text(
                    t.dontSeeYourPc,
                    textAlign: TextAlign.center,
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
