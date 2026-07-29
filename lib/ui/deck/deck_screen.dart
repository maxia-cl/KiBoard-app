import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../model/deck.dart';
import '../../net/layout_source.dart';
import '../../net/saved_session.dart';
import '../../net/trace.dart';
import '../../net/ws_layout_source.dart';
import '../pair/discover_screen.dart';
import '../tokens.g.dart';
import '../input/dictation_screen.dart';
import '../input/trackpad_screen.dart';
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

  @override
  void initState() {
    super.initState();
    // A key pad you have to wake up first is not a key pad. Android's screen timeout is ~30s, and
    // the deck's whole point is being glanceable and pressable without ceremony while you work on
    // the PC. Released in dispose, so it only applies while the deck is actually on screen.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  double? _lastTracedSize;

  /// Reports the sizing decision when it changes. The point of `sizeForDevice` is that the key
  /// does NOT resize on rotation, and eyeballing a screenshot cannot tell 118 from 120 — if the
  /// box cap (`byBox`) is ever the one chosen, the guarantee is broken and this says so.
  void _traceSize(double byDevice, double byBox, double chosen, double w, double h) {
    if (_lastTracedSize == chosen) return;
    _lastTracedSize = chosen;
    final capped = byBox < byDevice ? ' CAPPED BY BOX' : '';
    trace(
      'keySize=${chosen.toStringAsFixed(1)} device=${byDevice.toStringAsFixed(1)} '
      'box=${byBox.toStringAsFixed(1)} space=${w.toStringAsFixed(0)}x${h.toStringAsFixed(0)}$capped',
    );
  }

  /// Positions lit green right now, because the host confirmed them.
  final Set<int> _confirmed = {};

  /// Swipe between the pages of a deck (§4.4 `set_page`). The host owns the page — it answers with
  /// the `layout` for it — so there is no local page state to keep in sync.
  void _swipePage(Layout layout, double velocity) {
    if (velocity == 0 || layout.pages < 2) return;
    final next = (layout.page + (velocity < 0 ? 1 : -1)).clamp(0, layout.pages - 1);
    if (next == layout.page) return;
    HapticFeedback.selectionClick();
    trace('swipe -> page $next of ${layout.pages}');
    widget.session?.setPage(next);
  }

  Future<void> _handlePress(Layout layout, int pos, String press) async {
    final key = layout.keys[pos];
    // Confirms the press landed on the device before the host has answered. A key pad that does
    // not acknowledge a touch feels broken even when it works.
    HapticFeedback.selectionClick();

    if (key.action == 'windows') {
      widget.layoutSource.pressKey(pos: pos, press: press);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WindowSwitcherScreen(layoutSource: widget.layoutSource)),
      );
      return;
    }

    final session = widget.session;

    // §4.2.1: these name a screen on THIS phone, not work for the PC. Opening it is the whole
    // action — the press is never sent, and what reaches the host afterwards is `input`.
    if (session != null && (key.action == 'trackpad' || key.action == 'dictate')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => key.action == 'trackpad'
              ? TrackpadScreen(session: session)
              : DictationScreen(session: session),
        ),
      );
      return;
    }

    if (session == null) {
      widget.layoutSource.pressKey(pos: pos, press: press);
      return;
    }

    // §3.1: the key lights green ONLY when `key_result` arrives. Everything before that is the
    // phone talking to itself — this is the one signal that says the PC did it.
    try {
      final result = await session.pressResult(pos: pos, press: press);
      if (!mounted) return;
      if (result['type'] == 'key_result' && result['ok'] != true) {
        trace('key pos=$pos REFUSED: ${result['error']}');
        _showKeyError(result['error'] as String? ?? 'internal');
        return;
      }
      trace('key pos=$pos confirmed — lighting up');
      setState(() => _confirmed.add(pos));
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() => _confirmed.remove(pos));
    } on TimeoutException {
      if (mounted) _showKeyError('no answer from the PC');
    }
  }

  /// A key that failed has to say so. Silence reads as "it worked" — and the actions most likely
  /// to fail today are the ones F4 has not implemented (`launch:`, `focus:`), which would
  /// otherwise look like a dead key.
  void _showKeyError(String code) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(code),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(DeckTokens.accent),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
            // Sideways the chrome runs down the left instead of across the top. Height is what
            // limits the number of rows on a phone held that way — barely 390 logical pixels of it
            // against 870 of width — so the bar belongs on the axis that has room to spare.
            final sideways = MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
            final deck = Column(
              children: [
                if (!sideways) _TopBar(layout: layout, layoutSource: widget.layoutSource),
                if (widget.session != null) _LinkBanner(session: widget.session!),
                Expanded(
                  child: Padding(
                    // Sideways: no outer margin at all. The bezel is the device and the device is
                    // the screen (§3.0); a gap around it is a gap the keys pay for.
                    padding: sideways
                        ? const EdgeInsets.only(right: 4)
                        : const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Space the grid itself gets, after the bezel takes its share.
                        final w = constraints.maxWidth - DeviceBezel.chromeWidth();
                        final h = constraints.maxHeight -
                            DeviceBezel.chromeHeightFor(layout.pages, constraints.maxHeight,
                                dotsInside: !sideways);

                        // §3.1: the phone derives rows x cols from the space it has and tells the
                        // host. Rotating changes it, so this is checked on every layout pass —
                        // `setGrid` no-ops when nothing changed.
                        final wanted = AdaptiveGrid.forSpace(w, h);
                        widget.session?.setGrid(wanted);

                        // Keep drawing the grid the host last SENT: the new one only exists once
                        // its `layout` arrives, and painting 5 columns of a 2-column layout would
                        // flash a broken frame.
                        //
                        // The size comes from the DEVICE, not from this box, so rotating does not
                        // resize the keys. `sizeToFit` only caps it, in case a screen turns out
                        // tighter than the reserve assumed.
                        final byDevice = KeyGrid.sizeForDevice(MediaQuery.sizeOf(context), layout.grid);
                        final byBox = KeyGrid.sizeToFit(layout.grid, w, h);
                        final keySize = math.min(byDevice, byBox);
                        _traceSize(byDevice, byBox, keySize, w, h);
                        return SizedBox.expand(
                          // §4.4 `set_page`. The dots were drawn from the start but nothing ever
                          // moved between pages, so anything past the first screenful of a deck was
                          // unreachable. A key's tap recognizer loses the arena as soon as the
                          // pointer travels horizontally, so this does not swallow presses.
                          child: GestureDetector(
                            onHorizontalDragEnd: (d) => _swipePage(layout, d.primaryVelocity ?? 0),
                            child: DeviceBezel(
                              gridWidth: KeyGrid.widthFor(layout.grid, keySize),
                              gridHeight: KeyGrid.heightFor(layout.grid, keySize),
                              pageCount: layout.pages,
                              currentPage: layout.page,
                              dotsInside: !sideways,
                              child: KeyGrid(
                                grid: layout.grid,
                                keys: layout.keys,
                                keySize: keySize,
                                confirmed: _confirmed,
                                onKeyPress: (pos, press) => _handlePress(layout, pos, press),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
            if (!sideways) return deck;
            return Row(
              children: [
                _TopBar(layout: layout, layoutSource: widget.layoutSource, vertical: true),
                Expanded(child: deck),
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

/// The deck's chrome: which profile or deck is on show, the mode switch, and settings.
///
/// Runs along the TOP upright and down the SIDE sideways. Not decoration: height is the axis that
/// decides how many rows of keys fit, and a phone held sideways has barely 390 logical pixels of
/// it. Moving the bar onto the width — which has 870 to spare — is what buys the third row.
class _TopBar extends StatelessWidget {
  final Layout layout;
  final LayoutSource layoutSource;

  /// Sideways: the bar becomes a column on the left. ponytail: left because the branding already
  /// sat left and most people hold the right thumb over the keys — one constant to flip if that
  /// turns out backwards for someone.
  final bool vertical;

  const _TopBar({required this.layout, required this.layoutSource, this.vertical = false});

  @override
  Widget build(BuildContext context) {
    final title = layout.mode == 'auto' ? (layout.source.appName ?? 'Auto') : (layout.source.name ?? 'Manual');
    if (vertical) return _vertical(title);
    // Deliberately tight. Every pixel here is a pixel the keys do not get, and the keys are the
    // product — a DropdownButton at its default size alone ate ~48px of a phone held sideways.
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
      child: Row(
        children: [
          Icon(
            layout.mode == 'auto' ? Icons.bolt : Icons.dashboard_customize,
            color: const Color(DeckTokens.textSecondary),
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(DeckTokens.textPrimary),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownButton<String>(
            value: layout.mode,
            isDense: true,
            dropdownColor: const Color(0xFF1E1E20),
            underline: const SizedBox.shrink(),
            iconSize: 18,
            style: const TextStyle(color: Color(DeckTokens.textPrimary), fontSize: 12),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('Auto')),
              DropdownMenuItem(value: 'manual', child: Text('Manual')),
            ],
            onChanged: (mode) {
              if (mode != null) layoutSource.setMode(mode);
            },
          ),
          const SizedBox(width: 4),
          const Icon(Icons.settings, color: Color(DeckTokens.textSecondary), size: 18),
        ],
      ),
    );
  }

  /// The same three things stacked down a narrow strip. The title is rotated rather than dropped:
  /// in auto mode it names the app the pad is following, which is the one thing on this screen
  /// that answers "why are these keys the keys?".
  Widget _vertical(String title) {
    return SizedBox(
      width: _verticalWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 4, 8),
        child: Column(
          children: [
            Icon(
              layout.mode == 'auto' ? Icons.bolt : Icons.dashboard_customize,
              color: const Color(DeckTokens.textSecondary),
              size: 16,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: Center(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(DeckTokens.textPrimary),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            // The page indicator lives here sideways, not in the bezel: on the width, which has
            // room to spare, instead of the height, which is what caps the key size.
            if (layout.pages > 1) ...[
              for (var i = 0; i < layout.pages; i++) DeviceBezel.dot(i == layout.page),
              const SizedBox(height: 4),
            ],
            const SizedBox(height: 4),
            // Icon-only: a DropdownButton with its label does not fit a strip this narrow, and the
            // icon above already says which mode is on.
            SizedBox(
              height: 28,
              child: DropdownButton<String>(
                value: layout.mode,
                isDense: true,
                dropdownColor: const Color(0xFF1E1E20),
                underline: const SizedBox.shrink(),
                iconSize: 18,
                icon: const Icon(Icons.swap_vert, color: Color(DeckTokens.textSecondary), size: 18),
                selectedItemBuilder: (_) => const [SizedBox.shrink(), SizedBox.shrink()],
                style: const TextStyle(color: Color(DeckTokens.textPrimary), fontSize: 12),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Auto')),
                  DropdownMenuItem(value: 'manual', child: Text('Manual')),
                ],
                onChanged: (mode) {
                  if (mode != null) layoutSource.setMode(mode);
                },
              ),
            ),
            const SizedBox(height: 6),
            const Icon(Icons.settings, color: Color(DeckTokens.textSecondary), size: 18),
          ],
        ),
      ),
    );
  }

  /// Width of the side strip.
  static const _verticalWidth = 40.0;
}
