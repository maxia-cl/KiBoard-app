import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/deck.dart';
import '../../net/layout_source.dart';
import '../../net/saved_session.dart';
import '../../net/ws_layout_source.dart';
import '../pair/discover_screen.dart';
import '../tokens.g.dart';
import '../windows/window_switcher_screen.dart';
import 'adaptive_grid.dart';
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
            // The banner sits OUTSIDE this branch on purpose. Launching while the PC is asleep
            // produces no layout at all, and a bare spinner then says nothing — which is exactly
            // the failure mode this screen exists to avoid.
            if (!snapshot.hasData) {
              return Column(
                children: [
                  if (widget.session != null) _LinkBanner(session: widget.session!),
                  Expanded(child: _NoLayoutYet(session: widget.session, hostName: widget.hostName)),
                ],
              );
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
                        // Space the grid itself gets, after the bezel takes its share.
                        final w = constraints.maxWidth - 32 - DeviceBezel.chromeWidth();
                        final h = constraints.maxHeight - DeviceBezel.chromeHeightFor(layout.pages);

                        // §3.1: the phone derives rows x cols from the space it has and tells the
                        // host. Rotating changes it, so this is checked on every layout pass —
                        // `setGrid` no-ops when nothing changed.
                        final wanted = AdaptiveGrid.forSpace(w, h);
                        widget.session?.setGrid(wanted);

                        // Keep drawing the grid the host last SENT: the new one only exists once
                        // its `layout` arrives, and painting 8 columns of a 5-column layout would
                        // flash a broken frame.
                        final keySize = KeyGrid.sizeToFit(layout.grid, w, h);
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

/// What fills the screen before the first layout arrives.
///
/// Waiting on a connection that is being retried is NOT the same as waiting a moment for the first
/// frame, and a spinner cannot tell the two apart. Launching with the PC asleep is the common case
/// — the phone is in a pocket far more often than the desktop is awake — so it gets a sentence
/// rather than an animation that never ends.
class _NoLayoutYet extends StatelessWidget {
  final WsLayoutSource? session;
  final String hostName;
  const _NoLayoutYet({required this.session, required this.hostName});

  @override
  Widget build(BuildContext context) {
    final host = hostName.isEmpty ? 'your PC' : '"$hostName"';
    if (session == null) {
      return const Center(child: CircularProgressIndicator(color: Color(DeckTokens.accent)));
    }
    return StreamBuilder<SessionStatus>(
      stream: session!.status,
      initialData: session!.currentStatus,
      builder: (context, snapshot) {
        // Only spin while the link is actually up and the first layout is in flight — that is a
        // moment. Retrying cycles connecting/offline every few seconds, and spinning through that
        // would hide the explanation behind an animation for as long as the PC stays asleep.
        if (snapshot.data == SessionStatus.online) {
          return const Center(child: CircularProgressIndicator(color: Color(DeckTokens.accent)));
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              "Waiting for $host.\nIt will appear here as soon as the PC is awake and on this "
              "network.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(DeckTokens.textSecondary), height: 1.5),
            ),
          ),
        );
      },
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
