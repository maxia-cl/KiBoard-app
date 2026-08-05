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
import '../icons.dart';
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
    _launchTimer?.cancel();
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

  /// Positions painted brand red because a press asked an app to open and it is not up yet.
  ///
  /// The key stays that colour until the host's next push says `state.running`, which rides the
  /// 500 ms poll, so it clears by itself the moment the window appears. [_launchGiveUp] is the
  /// backstop for the app that never comes up at all — an installer prompt, a crash — because a
  /// key stuck red forever would be a worse lie than no colour.
  final Set<int> _launching = {};
  Timer? _launchTimer;
  static const _launchGiveUp = Duration(seconds: 20);

  void _markLaunching(int pos) {
    setState(() => _launching.add(pos));
    _launchTimer?.cancel();
    _launchTimer = Timer(_launchGiveUp, () {
      if (mounted) setState(_launching.clear);
    });
  }

  /// Clears the ones whose app is up. Called on every layout, since that is when the answer
  /// arrives — the host attaches `state.running` per send.
  void _clearLaunched(Layout layout) {
    if (_launching.isEmpty) return;
    final done = _launching.where((pos) {
      final key = pos < layout.keys.length ? layout.keys[pos] : null;
      return key == null || key.running == true;
    }).toSet();
    if (done.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _launching.removeAll(done));
      });
    }
  }

  /// What the last layout was of, so a page change can be told apart from a deck change.
  String? _lastSource;
  int _lastPage = 0;

  /// Which way the pages should travel: +1 when going forward, -1 when coming back.
  double _pageDir = 1;

  /// Short enough that the pad still feels like hardware, long enough to read as a move. Android's
  /// own page transitions sit around 300 ms; a control surface wants to be quicker than that.
  static const _pageSlide = Duration(milliseconds: 200);

  /// Identity of what is on screen. The deck as well as the page, so switching decks also swaps
  /// rather than mutating the same grid under the user.
  String _pageKey(Layout layout) => '${layout.mode}/${layout.source.id}#${layout.page}';

  /// Reads the direction of a page change out of the layouts as they arrive.
  ///
  /// The host owns the page, so the phone never decides it — but it does have to know which way
  /// the user went, or the new page would slide in from whichever side was hardcoded and half the
  /// swipes would animate backwards.
  void _trackPage(Layout layout) {
    final source = '${layout.mode}/${layout.source.id}';
    if (source != _lastSource) {
      // A different deck, or auto mode following a different app. Not a swipe, so there is no
      // direction to infer; leave the last one alone.
      _lastSource = source;
      _lastPage = layout.page;
      return;
    }
    if (layout.page != _lastPage) {
      _pageDir = layout.page > _lastPage ? 1 : -1;
      _lastPage = layout.page;
    }
  }

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

  /// §3: a `danger` key is painted red AND asks before it acts. Only the painting was ever built,
  /// so "Cerrar app" closed whatever was in front on a single mis-tap — on a surface hit from
  /// muscle memory, next to keys that are harmless.
  ///
  /// Long and double presses ask too: the gesture does not change what the key does.
  Future<bool> _confirmDanger(DeckKey key) async {
    final label = (key.label ?? '').isEmpty ? 'This key' : key.label!;
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E20),
        title: Text('$label?', style: const TextStyle(color: Color(DeckTokens.textPrimary))),
        content: const Text(
          'This one cannot be undone from here.',
          style: TextStyle(color: Color(DeckTokens.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(DeckTokens.textSecondary))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(DeckTokens.accent)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(label),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  Future<void> _handlePress(Layout layout, int pos, String press) async {
    final key = layout.keys[pos];
    // Confirms the press landed on the device before the host has answered. A key pad that does
    // not acknowledge a touch feels broken even when it works.
    HapticFeedback.selectionClick();

    // Asked BEFORE any of the branches below, so it covers a dangerous key whatever it does —
    // not only the ones that end up going to the host.
    if (key.danger && !await _confirmDanger(key)) {
      trace('danger key pos=$pos cancelled');
      return;
    }
    if (!mounted) return;

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
      // A key that opens an app carries `state.running: false` until it is up. That is the only
      // thing on the wire that says "this press starts something slow", so it is what decides
      // whether the key waits in red — the phone never sees the action itself (§4.2).
      if (key.running == false) {
        trace('key pos=$pos is launching — holding it red');
        _markLaunching(pos);
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
            _trackPage(layout);
            _clearLaunched(layout);
            // Sideways the chrome runs down the left instead of across the top. Height is what
            // limits the number of rows on a phone held that way — barely 390 logical pixels of it
            // against 870 of width — so the bar belongs on the axis that has room to spare.
            final sideways = MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
            final deck = Column(
              children: [
                if (!sideways) _TopBar(layout: layout, layoutSource: widget.layoutSource, session: widget.session),
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
                                dotsInside: true);

                        // §3.1: the phone derives rows x cols from the space it has and tells the
                        // host. Rotating changes it, so this is checked on every layout pass —
                        // `setGrid` no-ops when nothing changed.
                        final wanted = AdaptiveGrid.forSpace(w, h);
                        widget.session?.setGrid(wanted);

                        // Reshape to the new orientation IMMEDIATELY, without waiting for the
                        // host's answer. The grid is a fixed count that merely transposes, and
                        // pagination is by count — so the very same ten keys are on screen either
                        // way and only their arrangement changes. Waiting used to mean rendering
                        // five columns into a portrait box: `sizeToFit` then shrank the key to
                        // 57 pixels. With a host that lasted 150ms; with no host it never ended,
                        // which is what "the icons go tiny when I rotate" was.
                        //
                        // Capacity guards it: if the host ever sends a different number of keys
                        // than this grid holds, keep what it sent rather than reflow into a shape
                        // the keys do not fill.
                        final grid = wanted.capacity == layout.grid.capacity &&
                                layout.keys.length == wanted.capacity
                            ? wanted
                            : layout.grid;

                        // The size comes from the DEVICE, not from this box, so rotating does not
                        // resize the keys. `sizeToFit` only caps it, in case a screen turns out
                        // tighter than the reserve assumed.
                        final byDevice = KeyGrid.sizeForDevice(MediaQuery.sizeOf(context), grid);
                        final byBox = KeyGrid.sizeToFit(grid, w, h);
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
                              gridWidth: KeyGrid.widthFor(grid, keySize),
                              gridHeight: KeyGrid.heightFor(grid, keySize),
                              pageCount: layout.pages,
                              currentPage: layout.page,
                              // Under the keys in BOTH orientations. Sideways they used to live
                              // in the side strip, to keep their 18 px off the height that caps
                              // the key size — but the measured landscape box allows 94.2 px per
                              // key against the 79.1 the device asks for, so the reserve comes out
                              // of slack and the keys do not move. `CAPPED BY BOX` in the trace is
                              // what shouts if that stops being true on some other screen.
                              dotsInside: true,
                              // The page used to be REPLACED, which read as a cut rather than as
                              // a move. It travels now, in the direction the swipe went, clipped
                              // to the bezel so a page leaves through the edge of the device
                              // instead of over it.
                              child: ClipRect(
                                child: AnimatedSwitcher(
                                  duration: _pageSlide,
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  // Stacked rather than the default cross-fade-in-place: the two
                                  // pages have to pass each other, so both must be laid out.
                                  layoutBuilder: (current, previous) => Stack(
                                    alignment: Alignment.center,
                                    children: [...previous, ?current],
                                  ),
                                  transitionBuilder: (child, animation) {
                                    // The outgoing child runs this same animation in REVERSE, so
                                    // giving it the opposite start sends it out the far side while
                                    // the new one comes in from the near one.
                                    final incoming = (child.key as ValueKey<String>).value == _pageKey(layout);
                                    final from = Offset(incoming ? _pageDir : -_pageDir, 0);
                                    return SlideTransition(
                                      position: Tween(begin: from, end: Offset.zero).animate(animation),
                                      child: FadeTransition(opacity: animation, child: child),
                                    );
                                  },
                                  child: KeyGrid(
                                    key: ValueKey(_pageKey(layout)),
                                    grid: grid,
                                    keys: layout.keys,
                                    keySize: keySize,
                                    confirmed: _confirmed,
                                    launching: _launching,
                                    onKeyPress: (pos, press) => _handlePress(layout, pos, press),
                                  ),
                                ),
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
                _TopBar(layout: layout, layoutSource: widget.layoutSource, session: widget.session, vertical: true),
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

  /// The live session, when there is one — it is where the host's deck list lives. Null for the
  /// fixture-backed source used in tests, which has no host to have asked.
  final WsLayoutSource? session;

  /// Sideways: the bar becomes a column on the left. ponytail: left because the branding already
  /// sat left and most people hold the right thumb over the keys — one constant to flip if that
  /// turns out backwards for someone.
  final bool vertical;

  const _TopBar({
    required this.layout,
    required this.layoutSource,
    this.session,
    this.vertical = false,
  });

  /// What the deck control says: the deck on screen, or an invitation when auto mode means there
  /// is none.
  String get _deckLabel =>
      layout.mode == 'manual' ? (layout.source.name ?? 'Decks') : 'Decks';

  /// The deck list, and a way to ask for one (F7). Before this the phone could only reach the deck
  /// the host happened to put first, or one that another deck had a `deck:` key pointing at — a
  /// key slot per destination, and a new deck unreachable until someone wired it up.
  ///
  /// Picking a deck implies manual mode: it is the only mode a deck exists in, so asking for one
  /// while in auto can only mean "take me there".
  Future<void> _pickDeck(BuildContext context) async {
    final live = session;
    if (live == null) return;
    final decks = live.decks;
    if (decks.isEmpty) return;
    final current = layout.mode == 'manual' ? layout.source.id : null;

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E20),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final deck in decks)
                ListTile(
                  leading: Icon(
                    iconForDeck(deck.icon),
                    color: Color(deck.id == current ? DeckTokens.accent : DeckTokens.textSecondary),
                  ),
                  title: Text(
                    deck.name,
                    style: TextStyle(
                      color: Color(
                        deck.id == current ? DeckTokens.accent : DeckTokens.textPrimary,
                      ),
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(deck.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) await live.setMode('manual', deckId: chosen);
  }

  @override
  Widget build(BuildContext context) {
    final title = layout.mode == 'auto' ? (layout.source.appName ?? 'Auto') : (layout.source.name ?? 'Manual');
    if (vertical) return _vertical(context, title);
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
          if (session != null && session!.decks.isNotEmpty)
            TextButton.icon(
              onPressed: () => _pickDeck(context),
              icon: const Icon(Icons.dashboard, size: 16, color: Color(DeckTokens.textSecondary)),
              label: Text(
                _deckLabel,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(DeckTokens.textSecondary), fontSize: 12),
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
          // The settings cog that used to sit here was a bare `Icon` with no handler in either
          // orientation — it has done nothing since F3. Removed rather than enlarged: there is no
          // settings screen to open yet, and a control that cannot be pressed is worse than no
          // control, especially on a screen where the complaint is that things cannot be pressed.
          // One line to put back when F7 gives it somewhere to go.
        ],
      ),
    );
  }

  /// The title and the mode switch stacked down the strip. The title is rotated rather than
  /// dropped: in auto mode it names the app the pad is following, which is the one thing on this
  /// screen that answers "why are these keys the keys?".
  Widget _vertical(BuildContext context, String title) {
    return SizedBox(
      width: _verticalWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Column(
          children: [
            if (session != null && session!.decks.isNotEmpty)
              _StripButton(
                icon: Icons.dashboard,
                label: _deckLabel,
                onTap: () => _pickDeck(context),
              ),
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
            // A toggle, not a dropdown. There are exactly two modes, so a menu was a second tap
            // for nothing — and the icon-only DropdownButton it replaces had a hit area of about
            // 18x28 in a 40-wide strip, which is what "casi no se pueden presionar" was. This is
            // 56x56: above Material's 48 minimum, and it says which mode is on instead of hiding
            // it behind the menu.
            _StripButton(
              icon: layout.mode == 'auto' ? Icons.bolt : Icons.dashboard_customize,
              label: layout.mode == 'auto' ? 'Auto' : 'Manual',
              onTap: () => layoutSource.setMode(layout.mode == 'auto' ? 'manual' : 'auto'),
            ),
          ],
        ),
      ),
    );
  }

  /// Width of the side strip.
  ///
  /// 72, not 40. Sideways this comes off the WIDTH, which is the axis with room to spare — the key
  /// size is set by `sizeForDevice` from the screen, and `sizeToFit` only caps it, with about 80
  /// logical pixels of slack before it would. Spending 32 of those on a control people can
  /// actually hit is the trade this strip exists to make. `CAPPED BY BOX` in the trace says so out
  /// loud if that slack is ever wrong.
  static const _verticalWidth = 72.0;

  /// Material's minimum touch target is 48. 56 leaves room for a label under the icon.
  static const _tapTarget = 56.0;
}

/// One control in the side strip: 56x56, an icon and a word. Both the deck picker and the mode
/// toggle are this — the strip is narrow enough that two shapes would read as two kinds of thing.
class _StripButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StripButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: const Color(DeckTokens.keyDefaultBackground),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: _TopBar._tapTarget,
            height: _TopBar._tapTarget,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(DeckTokens.textPrimary), size: 20),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(DeckTokens.textSecondary), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
