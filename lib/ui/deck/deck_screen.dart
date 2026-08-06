import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../model/deck.dart';
import '../../net/layout_source.dart';
import '../../net/saved_session.dart';
import '../../net/trace.dart';
import '../../settings.dart';
import '../../net/ws_layout_source.dart';
import '../../l10n/app_localizations.dart';
import '../icons.dart';
import '../nav.dart';
import '../settings_sheet.dart';
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

  const DeckScreen({super.key, required this.layoutSource, required this.hostName, this.session});

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
    for (final t in _launchTimers.values) {
      t.cancel();
    }
    _swipeGuard?.cancel();
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

  /// Positions tinted with the brand colour because a press asked an app to come up.
  ///
  /// Two things end it, whichever lands first: the host reporting `state.running` for that key, or
  /// [_launchGrace]. The flag alone is not enough — it comes from matching a window back to the id
  /// that launched it, and on the phone it was still reporting `false` with the window already
  /// open, which left the deck looking like the press did nothing on one press and worked on the
  /// next. The timer is what makes the feedback the same every time; the flag is what lets it end
  /// early when it is right.
  final Set<int> _launching = {};
  final Map<int, Timer> _launchTimers = {};
  static const _launchGrace = Duration(seconds: 6);

  void _markLaunching(int pos) {
    setState(() => _launching.add(pos));
    _launchTimers.remove(pos)?.cancel();
    _launchTimers[pos] = Timer(_launchGrace, () => _stopLaunching(pos));
  }

  void _stopLaunching(int pos) {
    _launchTimers.remove(pos)?.cancel();
    if (mounted && _launching.contains(pos)) setState(() => _launching.remove(pos));
  }

  /// Ends the wait early for keys whose app the host now reports as up. Called on every layout,
  /// since that is when the answer arrives.
  void _clearLaunched(Layout layout) {
    if (_launching.isEmpty) return;
    final done = _launching
        .where((pos) => pos >= layout.keys.length || layout.keys[pos].running == true)
        .toList();
    if (done.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final pos in done) {
        _stopLaunching(pos);
      }
    });
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
      // The page the swipe asked for has arrived. This runs during build, so it lands on the
      // INCOMING subtree only — the outgoing one keeps the offset it was last built with and
      // carries on out from there, which is what makes the swap continue the gesture instead of
      // starting a second, separate move.
      _swipeGuard?.cancel();
      _dragDx = 0;
    }
  }

  // --- the page swipe (§4.4 `set_page`) -------------------------------------
  //
  // The host owns the page and answers with the `layout` for it, so there is no local page state
  // to keep in sync — but there IS a gesture to answer to, and it used to answer only on release:
  // nothing moved while the finger did, and a slow drag (`primaryVelocity` ~ 0) did nothing at all.
  // That is what "se queda pegado" was.
  //
  // What moves is the CURRENT page. The phone only ever holds the one the host sent, so there is
  // no neighbour to bring in behind it; the gap shows the bezel, which reads as the page being
  // pushed aside rather than as a missing screen.

  /// Where the page sits relative to home, in pixels. Positive is dragged right (going back).
  double _dragDx = 0;
  bool _dragging = false;

  /// Set while a committed swipe waits for the host's answer, so a page that is on its way out
  /// cannot be left out there by a host that never replies. See [_swipeTimeout].
  Timer? _swipeGuard;

  /// Springing home, and carrying a committed page the rest of the way out.
  static const _settle = Duration(milliseconds: 160);

  /// A host that has not answered by now is asleep, not slow — the deck stays up while offline
  /// (that is what the link banner is for), so the page has to come back rather than hang off
  /// the edge of the screen.
  static const _swipeTimeout = Duration(milliseconds: 400);

  void _dragUpdate(Layout layout, double delta) {
    // Resistance at the two ends, the way a list rubber-bands: it still moves, so the gesture is
    // never dead under the finger, but it says there is nothing over there.
    final pushingPastEnd =
        (delta < 0 && layout.page >= layout.pages - 1) || (delta > 0 && layout.page <= 0);
    setState(() {
      _dragging = true;
      _dragDx += pushingPastEnd ? delta * 0.25 : delta;
    });
  }

  void _dragEnd(Layout layout, double velocity, double width) {
    _dragging = false;
    // Either a long drag or a quick flick commits. Distance is the half that was missing — a slow,
    // deliberate drag across the whole pad ends at zero velocity and used to change nothing.
    final far = _dragDx.abs() > width * 0.25;
    final fast = velocity.abs() > 320;
    final dir = (_dragDx != 0 ? _dragDx < 0 : velocity < 0) ? 1 : -1;
    final next = (layout.page + dir).clamp(0, layout.pages - 1);

    if (layout.pages < 2 || !(far || fast) || next == layout.page) {
      setState(() => _dragDx = 0); // springs home over `_settle`
      return;
    }

    if (Settings.instance.value.haptics) HapticFeedback.selectionClick();
    trace('swipe -> page $next of ${layout.pages}');
    // Keep going the way the finger was going. The swap catches it part way out, and the outgoing
    // page keeps this offset because it is the widget that was already built — only the incoming
    // one is rebuilt, at zero.
    setState(() => _dragDx = -dir * width);
    _swipeGuard?.cancel();
    _swipeGuard = Timer(_swipeTimeout, () {
      if (!mounted || _dragDx == 0) return;
      trace('no layout for the swipe — putting the page back');
      setState(() => _dragDx = 0);
    });
    widget.session?.setPage(next);
  }

  /// §3: a `danger` key is painted red AND asks before it acts. Only the painting was ever built,
  /// so "Cerrar app" closed whatever was in front on a single mis-tap — on a surface hit from
  /// muscle memory, next to keys that are harmless.
  ///
  /// Long and double presses ask too: the gesture does not change what the key does.
  Future<bool> _confirmDanger(DeckKey key) async {
    final t = AppLocalizations.of(context)!;
    final label = (key.label ?? '').isEmpty ? 'This key' : key.label!;
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E20),
        title: Text('$label?', style: const TextStyle(color: Color(DeckTokens.textPrimary))),
        content: Text(t.cannotUndo, style: TextStyle(color: Color(DeckTokens.textSecondary))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.cancel, style: TextStyle(color: Color(DeckTokens.textSecondary))),
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
    // Asked BEFORE any of the branches below, so it covers a dangerous key whatever it does —
    // not only the ones that end up going to the host.
    if (key.danger && !await _confirmDanger(key)) {
      trace('danger key pos=$pos cancelled');
      return;
    }
    if (!mounted) return;

    if (key.action == 'windows') {
      widget.layoutSource.pressKey(pos: pos, press: press);
      Navigator.of(
        context,
      ).push(screenRoute(WindowSwitcherScreen(layoutSource: widget.layoutSource)));
      return;
    }

    final session = widget.session;

    // §4.2.1: these name a screen on THIS phone, not work for the PC. Opening it is the whole
    // action — the press is never sent, and what reaches the host afterwards is `input`.
    if (session != null && (key.action == 'trackpad' || key.action == 'dictate')) {
      Navigator.of(context).push(
        screenRoute(
          key.action == 'trackpad'
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

    // Marked BEFORE the round trip, not after it. `state.running` is present only on keys that
    // open an app — null on every other key (§4.2: the phone never sees the action) — so the phone
    // already knows this press starts something slow, and waiting for `key_result` to say so let
    // the cap spring back up for the ~20 ms in between. That blink was the whole complaint.
    //
    // If the host then REFUSES the press, the catch below puts the key back up.
    if (key.running != null) {
      trace('key pos=$pos opens an app — holding it down while it comes up');
      _markLaunching(pos);
    }

    try {
      final result = await session.pressResult(pos: pos, press: press);
      if (!mounted) return;
      if (result['type'] == 'key_result' && result['ok'] != true) {
        trace('key pos=$pos REFUSED: ${result['error']}');
        _stopLaunching(pos);
        _showKeyError(result['error'] as String? ?? 'internal');
        return;
      }
      trace('key pos=$pos confirmed');
    } on TimeoutException {
      _stopLaunching(pos);
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
                  Expanded(
                    child: _NoLayoutYet(session: widget.session, hostName: widget.hostName),
                  ),
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
            // Sideways the key is bound by HEIGHT, and the system bars own 40 of the 393 the phone
            // has. Three rows at the upright size need 369; hiding the bars is what closes that
            // gap, and it is what §3.0 asks for anyway — the device IS the screen. Upright there
            // is height to spare, so the bars stay: a clock is worth more than a bigger key there.
            SystemChrome.setEnabledSystemUIMode(
              sideways ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
            );
            final deck = Column(
              children: [
                if (!sideways)
                  _TopBar(
                    layout: layout,
                    layoutSource: widget.layoutSource,
                    session: widget.session,
                  ),
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
                        final h =
                            constraints.maxHeight -
                            DeviceBezel.chromeHeightFor(
                              layout.pages,
                              constraints.maxHeight,
                              dotsInside: true,
                            );

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
                        final grid =
                            wanted.capacity == layout.grid.capacity &&
                                layout.keys.length == wanted.capacity
                            ? wanted
                            : layout.grid;

                        // The DEVICE decides and the box only caps, which is what makes the key
                        // the same size however the phone is held (F3). Both reserves were
                        // re-measured after the bezel and the system bars stopped taking what they
                        // used to: at the old numbers this held the key at 95 inside a box that
                        // fits 112.
                        final byDevice = KeyGrid.sizeForDevice(MediaQuery.sizeOf(context), grid);
                        final byBox = KeyGrid.sizeToFit(grid, w, h);
                        // 2% off the key, given to the top edge of the frame below. The pad was
                        // sitting hard against the top of the device and the gap reads as breathing
                        // room around a real one.
                        final keySize = math.min(byDevice, byBox) * 0.98;
                        _traceSize(byDevice, byBox, keySize, w, h);
                        return SizedBox.expand(
                          // §4.4 `set_page`. The dots were drawn from the start but nothing ever
                          // moved between pages, so anything past the first screenful of a deck was
                          // unreachable. A key's tap recognizer loses the arena as soon as the
                          // pointer travels horizontally, so this does not swallow presses.
                          child: GestureDetector(
                            onHorizontalDragUpdate: (d) => _dragUpdate(layout, d.delta.dx),
                            onHorizontalDragEnd: (d) => _dragEnd(
                              layout,
                              d.primaryVelocity ?? 0,
                              KeyGrid.widthFor(grid, keySize),
                            ),
                            onHorizontalDragCancel: () => setState(() {
                              _dragging = false;
                              _dragDx = 0;
                            }),
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
                                    final incoming =
                                        (child.key as ValueKey<String>).value == _pageKey(layout);
                                    final from = Offset(incoming ? _pageDir : -_pageDir, 0);
                                    return SlideTransition(
                                      position: Tween(
                                        begin: from,
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: FadeTransition(opacity: animation, child: child),
                                    );
                                  },
                                  // The key is on the wrapper, not on the grid: the offset has to
                                  // belong to the page, so that the outgoing one keeps it.
                                  child: KeyedSubtree(
                                    key: ValueKey(_pageKey(layout)),
                                    // Zero duration while the finger is down, so the page IS the
                                    // finger; `_settle` once it lifts, to spring home or to carry
                                    // a committed page the rest of the way out. No controller and
                                    // nothing to dispose.
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(end: _dragDx),
                                      duration: _dragging ? Duration.zero : _settle,
                                      curve: Curves.easeOut,
                                      builder: (context, dx, child) =>
                                          Transform.translate(offset: Offset(dx, 0), child: child),
                                      child: KeyGrid(
                                        grid: grid,
                                        keys: layout.keys,
                                        keySize: keySize,
                                        launching: _launching,
                                        onKeyPress: (pos, press) =>
                                            _handlePress(layout, pos, press),
                                      ),
                                    ),
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
                _TopBar(
                  layout: layout,
                  layoutSource: widget.layoutSource,
                  session: widget.session,
                  vertical: true,
                ),
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
    final t = AppLocalizations.of(context)!;
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
            text: t.revoked,
            action: TextButton(
              onPressed: () async {
                await SavedSession.clear();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(fadeRoute(DiscoverScreen()));
              },
              child: Text(t.pairAgain),
            ),
          );
        }
        return _Banner(
          colour: const Color(0xFF3A3A3C),
          text: status == SessionStatus.connecting ? 'Connecting…' : t.offlineRetrying,
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
  String _deckLabel(AppLocalizations t) =>
      layout.mode == 'manual' ? (layout.source.name ?? t.decks) : t.decks;

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
                      color: Color(deck.id == current ? DeckTokens.accent : DeckTokens.textPrimary),
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
    final t = AppLocalizations.of(context)!;
    final title = layout.mode == 'auto'
        ? (layout.source.appName ?? 'Auto')
        : (layout.source.name ?? 'Manual');
    if (vertical) return _vertical(context, title);
    // Deliberately tight. Every pixel here is a pixel the keys do not get, and the keys are the
    // product — a DropdownButton at its default size alone ate ~48px of a phone held sideways.
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
      child: Row(
        children: [
          // 20/15 across the row: the scale the mode dropdown used to draw itself at, which is
          // the one that reads at arm's length. Only upright — sideways the height it costs comes
          // straight off the keys, and there the strip has its own sizes.
          Icon(
            layout.mode == 'auto' ? Icons.bolt : Icons.dashboard_customize,
            color: const Color(DeckTokens.textSecondary),
            size: 20,
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
          // Upright uses the SAME control as the side strip: a 56x56 tile with its icon and its
          // word. The size was picked in F5 because an icon-only dropdown in a 40-wide strip left
          // a hit area of about 18x28 — "casi no se pueden presionar" — and nothing about holding
          // the phone the other way makes a small target easier to hit. One widget for both, so
          // the two orientations cannot drift apart on two numbers nobody remembers to sync.
          if (session != null && session!.decks.isNotEmpty)
            _StripButton(
              icon: Icons.dashboard,
              label: _deckLabel(t),
              onTap: () => _pickDeck(context),
            ),
          const SizedBox(width: 6),
          _StripButton(
            icon: layout.mode == 'auto' ? Icons.bolt : Icons.dashboard_customize,
            label: layout.mode == 'auto' ? t.auto : t.manual,
            onTap: () => layoutSource.setMode(layout.mode == 'auto' ? 'manual' : 'auto'),
          ),
          const SizedBox(width: 6),
          // The cog is back, and this time it opens something. It was removed in F7 precisely
          // because it did not: a control that cannot be pressed is worse than no control.
          _StripButton(
            icon: Icons.settings,
            label: t.settings,
            onTap: () => showSettingsSheet(context),
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
    final t = AppLocalizations.of(context)!;
    return SizedBox(
      width: _verticalWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Column(
          children: [
            if (session != null && session!.decks.isNotEmpty)
              _StripButton(
                icon: Icons.dashboard,
                label: _deckLabel(t),
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
              icon: Icons.settings,
              label: t.settings,
              onTap: () => showSettingsSheet(context),
            ),
            _StripButton(
              icon: layout.mode == 'auto' ? Icons.bolt : Icons.dashboard_customize,
              label: layout.mode == 'auto' ? t.auto : t.manual,
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
