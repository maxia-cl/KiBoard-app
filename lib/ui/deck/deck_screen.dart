import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/deck.dart';
import '../../net/layout_source.dart';
import '../../net/saved_session.dart';
import '../../net/ws_layout_source.dart';
import '../pair/discover_screen.dart';
import '../tokens.g.dart';
import '../windows/window_switcher_screen.dart';
import 'device_bezel.dart';
import 'key_grid.dart';

class DeckScreen extends StatefulWidget {
  final LayoutSource layoutSource;
  final String hostName;

  /// The live session, when there is one. Null for the fixture-backed source used in tests: it has
  /// no socket, so there is no connection state to report.
  final WsLayoutSource? session;

  const DeckScreen({
    super.key,
    required this.layoutSource,
    required this.hostName,
    this.session,
  });

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  late final Stream<Layout> _layouts = widget.layoutSource.layouts();

  void _handlePress(Layout layout, int pos, String press) {
    final key = layout.keys[pos];
    // Confirms the press landed on the device before the host has answered. A key pad that does
    // not acknowledge a touch feels broken even when it works.
    HapticFeedback.selectionClick();
    widget.layoutSource.pressKey(pos: pos, press: press);
    if (key.action == 'windows') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WindowSwitcherScreen(layoutSource: widget.layoutSource)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: SafeArea(
        child: StreamBuilder<Layout>(
          stream: _layouts,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Color(DeckTokens.accent)));
            }
            final layout = snapshot.data!;
            return Column(
              children: [
                _TopBar(layout: layout, layoutSource: widget.layoutSource),
                if (widget.session != null) _LinkBanner(session: widget.session!),
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Both axes, minus everything the bezel puts around the grid — sizing off
                        // width alone overflowed the moment the phone was turned sideways.
                        final keySize = KeyGrid.sizeToFit(
                          layout.grid,
                          constraints.maxWidth - 32 - DeviceBezel.chromeWidth(),
                          constraints.maxHeight - DeviceBezel.chromeHeightFor(layout.pages),
                        );
                        return DeviceBezel(
                          gridWidth: KeyGrid.widthFor(layout.grid, keySize),
                          gridHeight: KeyGrid.heightFor(layout.grid, keySize),
                          pageCount: layout.pages,
                          currentPage: layout.page,
                          child: KeyGrid(
                            grid: layout.grid,
                            keys: layout.keys,
                            keySize: keySize,
                            onKeyPress: (pos, press) => _handlePress(layout, pos, press),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shows the link only when there is something to say. Silent while online: a permanent "connected"
/// badge is noise on a key pad whose whole job is to be glanceable.
class _LinkBanner extends StatelessWidget {
  final WsLayoutSource session;
  const _LinkBanner({required this.session});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SessionStatus>(
      stream: session.status,
      initialData: session.currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? SessionStatus.connecting;
        if (status == SessionStatus.online) return const SizedBox.shrink();

        // A revoked token cannot be retried out of: the only way forward is pairing again.
        if (status == SessionStatus.dead) {
          return _Banner(
            colour: const Color(DeckTokens.accent),
            text: 'This PC revoked access.',
            action: TextButton(
              onPressed: () async {
                await SavedSession.clear();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => DiscoverScreen()),
                );
              },
              child: const Text('Pair again'),
            ),
          );
        }
        return _Banner(
          colour: const Color(0xFF3A3A3C),
          text: status == SessionStatus.connecting ? 'Connecting…' : 'Offline — retrying…',
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  final Color colour;
  final String text;
  final Widget? action;
  const _Banner({required this.colour, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: colour,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final Layout layout;
  final LayoutSource layoutSource;
  const _TopBar({required this.layout, required this.layoutSource});

  @override
  Widget build(BuildContext context) {
    final title = layout.mode == 'auto' ? (layout.source.appName ?? 'Auto') : (layout.source.name ?? 'Manual');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            layout.mode == 'auto' ? Icons.bolt : Icons.dashboard_customize,
            color: const Color(DeckTokens.textSecondary),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Color(DeckTokens.textPrimary), fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownButton<String>(
            value: layout.mode,
            dropdownColor: const Color(0xFF1E1E20),
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Color(DeckTokens.textPrimary), fontSize: 13),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('Auto')),
              DropdownMenuItem(value: 'manual', child: Text('Manual')),
            ],
            onChanged: (mode) {
              if (mode != null) layoutSource.setMode(mode);
            },
          ),
          const SizedBox(width: 8),
          Icon(Icons.settings, color: const Color(DeckTokens.textSecondary), size: 20),
        ],
      ),
    );
  }
}
