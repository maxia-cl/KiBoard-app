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
import 'key_widget.dart';

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

  /// Watches for the app coming back to the foreground. The phone spends most of its life in a
  /// pocket while the PC sleeps, so `resumed` is the single most frequent transition in the
  /// product — and the moment the user has just woken the PC and wants to press a key.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => widget.session?.reconnectNow(),
  );

  StreamSubscription<String>? _toasts;

  @override
  void initState() {
    super.initState();
    _lifecycle; // created lazily; touch it so it is listening from the first frame
    // §4.4. The host was talking and nothing was listening: every `toast` it sent was filtered
    // out and dropped, which is why "Profile imported" never appeared anywhere.
    _toasts = widget.layoutSource.toasts().listen((text) {
      if (mounted) _showKeyError(text);
    });
    // A key pad you have to wake up first is not a key pad. Android's screen timeout is ~30s, and
    // the deck's whole point is being glanceable and pressable without ceremony while you work on
    // the PC. Released in dispose, so it only applies while the deck is actually on screen.
    WakelockPlus.enable();
    // §4.1 `page_preload`. No `setState`: these change nothing on screen, they only make the next
    // swipe have something to draw. The build that matters is the one the drag already triggers.
    _preloads = widget.layoutSource.preloads().listen(_remember);
  }

  @override
  void dispose() {
    for (final t in _launchTimers.values) {
      t.cancel();
    }
    _swipeGuard?.cancel();
    _preloads?.cancel();
    _toasts?.cancel();
    _exitArmed?.cancel();
    _lifecycle.dispose();
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

  String? _lastShape;

  /// What actually arrived, versus the grid being drawn. The two disagreeing is invisible on
  /// screen — a short page and a padded one look identical — and it is the first thing to check
  /// when the pad has a hole in it or a cell too many.
  void _traceShape(Layout layout, Grid grid) {
    final shape =
        '${layout.mode}/${layout.source.id} keys=${layout.keys.length} '
        'grid=${grid.rows}x${grid.cols} page=${layout.page}/${layout.pages}';
    if (_lastShape == shape) return;
    _lastShape = shape;
    trace(shape);
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
      // A different deck entirely. Its pages are not this one's, and keeping them would grow the
      // cache by every deck ever opened for the sake of pages nothing can swipe to.
      _seen.clear();
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

  /// The app in the foreground on the PC. Null only when the host has not resolved one.
  ///
  /// **Both modes, and every page.** The title names it in auto, but a line of 14 pt text in the
  /// chrome is not what somebody glancing at a pad from across a desk reads — the icon is. It sits
  /// bottom-right of the grid in both orientations, which is a different PAIR of cells upright and
  /// sideways because the grid transposes. That is the intent, not a side effect.
  ///
  /// Those two cells are RESERVED (§4.1 `grid.reserve`), so it never has to fight a key for them —
  /// which is what made it appear only on the pages that happened to have room.
  String? _foregroundApp(Layout layout) {
    final name = layout.source.appName;
    return (name == null || name.isEmpty) ? null : name;
  }

  /// How many cells wide the panel is: the two reserved ones, plus any UNLIT cells trailing them
  /// on the same row.
  ///
  /// A page whose keys stop short left one lonely unlit cap wedged between the last key and the
  /// panel, and one gap in an otherwise solid row reads as a drawing fault rather than as a key
  /// nobody has used. Absorbing it can never hide anything: it only ever takes cells the host left
  /// empty, and it stops at the row's edge.
  int _panelCells(Layout layout, Grid grid) {
    var cells = reservedCells;
    // Walk back from the last key the host sent, while it is empty and still on the bottom row.
    var i = layout.keys.length - 1;
    while (i >= 0 &&
        layout.keys[i].kind == KeyKind.empty &&
        cells < grid.cols &&
        (i % grid.cols) != grid.cols - 1) {
      cells++;
      i--;
    }
    return cells;
  }

  /// The keys the grid actually draws: everything the host sent, minus the unlit cells the panel
  /// has swallowed. See [_panelCells].
  List<DeckKey> _keysUnder(Layout layout, Grid grid) {
    final absorbed = _panelCells(layout, grid) - reservedCells;
    if (absorbed <= 0) return layout.keys;
    return layout.keys.sublist(0, layout.keys.length - absorbed);
  }

  /// Remembers a page so a swipe towards it has something to draw.
  void _remember(Layout layout) {
    _seen[_seenKey(layout, layout.page)] = layout;
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

  /// Finger down: the page tracks it with no animation at all.
  bool _dragging = false;

  /// Finger down OR still settling. What it gates is drawing the neighbouring pages — they are
  /// off-screen and clipped at rest, so building them on every layout push would be work for
  /// nothing, but they have to stay up for the whole spring-back and not blink out on release.
  bool _swiping = false;

  /// Pages this phone holds but is not on, so the one you are dragging towards can be drawn coming
  /// in behind instead of a black gap.
  ///
  /// Two sources, and they cover each other: every page that has been ON screen, and §4.1
  /// `page_preload` — the neighbours the host sends unasked right after each layout, which is what
  /// makes the FIRST swipe onto a page work too. The phone never asks for a page: the only way to
  /// ask is `set_page`, which moves the host's page cursor, and its pushes render from that cursor.
  final Map<String, Layout> _seen = {};
  StreamSubscription<Layout>? _preloads;

  /// Identity of one page of one surface, for [_seen].
  ///
  /// Keyed on the grid's CAPACITY, not its shape: a layout is paginated for a number of keys, and
  /// this screen re-shapes 5×3 to 3×5 itself when the count matches (see `build`). Keying on
  /// rows×cols would miss every page cached in the other orientation while holding exactly the
  /// keys that belong on screen. A genuinely different capacity paginates differently and misses,
  /// which is right.
  String _seenKey(Layout l, int page) => '${l.mode}/${l.source.id}/${l.grid.capacity}#$page';

  /// The page on one side of this one, if the phone has it. Null is the honest answer, and the
  /// caller draws nothing rather than guessing.
  Layout? _neighbour(Layout layout, int delta) {
    final page = layout.page + delta;
    if (page < 0 || page >= layout.pages) return null;
    return _seen[_seenKey(layout, page)];
  }

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
      _swiping = true;
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
      // The list comes from the PC, so with the link down this pushes a screen that cannot fill
      // itself — and the un-awaited press below would throw its timeout into nowhere as well.
      // Saying so here beats an eight-second wait for a message.
      final live = widget.session;
      if (live != null && live.currentStatus != SessionStatus.online) {
        _showKeyError(AppLocalizations.of(context)!.windowsFailed);
        return;
      }
      unawaited(widget.layoutSource.pressKey(pos: pos, press: press));
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
        _showKeyError(_pressError(result['error'] as String? ?? 'internal'));
        return;
      }
      trace('key pos=$pos confirmed');
    } on TimeoutException {
      _stopLaunching(pos);
      if (mounted) _showKeyError(AppLocalizations.of(context)!.noAnswer);
    }
  }

  /// A §5 error code turned into a sentence. The code went straight into the snackbar, so a
  /// refused press read `unknown_action` — a protocol identifier, in English, to somebody who
  /// pressed a key. The pairing screen has done this properly with its own codes all along.
  String _pressError(String code) {
    final t = AppLocalizations.of(context)!;
    return switch (code) {
      'no_such_key' => t.noSuchKey,
      'unknown_action' => t.unknownAction,
      'blocked_action' => t.blockedAction,
      _ => t.keyRefusedGeneric,
    };
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

  /// Armed by one back press and disarmed by [_exitWindow]. A timer rather than a stored timestamp
  /// so the state clears ITSELF — a timestamp compared against `DateTime.now()` leaves the deck
  /// permanently one press from closing once the user has ever pressed back, and is invisible to a
  /// test's clock.
  Timer? _exitArmed;
  static const _exitWindow = Duration(seconds: 2);

  /// Back on the deck used to do one of two things depending on how you got here, and neither was
  /// intended: on a relaunch the deck is the root route, so back closed the app outright; in the
  /// session where you paired it popped to the discovery list you had already finished, with no
  /// route forward. The route stack is now the same either way (see `pairing_code_screen`), and
  /// this makes leaving deliberate.
  ///
  /// Two seconds, and the confirmation is a snackbar rather than a dialog: the deck is poked at
  /// while looking at a monitor, and a modal there would be worse than the accident it prevents.
  void _confirmExit() {
    if (_exitArmed?.isActive ?? false) {
      _exitArmed?.cancel();
      SystemNavigator.pop();
      return;
    }
    _exitArmed = Timer(_exitWindow, () {});
    if (Settings.instance.value.haptics) HapticFeedback.selectionClick();
    final t = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(t.backAgainToLeave),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2C2C2E),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: _buildDeck(context),
    );
  }

  Widget _buildDeck(BuildContext context) {
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
                        _traceShape(layout, grid);
                        _remember(layout);
                        return SizedBox.expand(
                          // §4.4 `set_page`. The dots were drawn from the start but nothing ever
                          // moved between pages, so anything past the first screenful of a deck was
                          // unreachable. A key's tap recognizer loses the arena as soon as the
                          // pointer travels horizontally, so this does not swallow presses.
                          // The page swipe is a raw drag, which a screen reader cannot perform —
                          // so without this there is no accessible way to leave page 1 at all.
                          // `explicitChildNodes` keeps the keys as their own nodes rather than
                          // merging the whole pad into one announcement.
                          child: Semantics(
                            container: layout.pages > 1,
                            explicitChildNodes: true,
                            // All three, not just `value`: Flutter asserts that a node offering
                            // increase/decrease says what the value would become.
                            value: layout.pages > 1 ? '${layout.page + 1}/${layout.pages}' : null,
                            increasedValue: layout.pages > 1
                                ? '${(layout.page + 2).clamp(1, layout.pages)}/${layout.pages}'
                                : null,
                            decreasedValue: layout.pages > 1
                                ? '${layout.page.clamp(1, layout.pages)}/${layout.pages}'
                                : null,
                            onIncrease: layout.page + 1 < layout.pages
                                ? () => widget.session?.setPage(layout.page + 1)
                                : null,
                            onDecrease: layout.page > 0
                                ? () => widget.session?.setPage(layout.page - 1)
                                : null,
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
                                        onEnd: () {
                                          if (mounted && _dragDx == 0 && _swiping) {
                                            setState(() => _swiping = false);
                                          }
                                        },
                                        builder: (context, dx, child) => Transform.translate(
                                          offset: Offset(dx, 0),
                                          child: child,
                                        ),
                                        // The neighbours ride INSIDE the same transform, one page
                                        // plus a gap out on either side, so they come in behind the
                                        // finger without any second animation to keep in step.
                                        // `Positioned` keeps them out of the Stack's sizing and the
                                        // ClipRect above cuts them at the edge of the device.
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            KeyGrid(
                                              grid: grid,
                                              // Stops where the panel starts. Absorbing a cell and
                                              // then still drawing its cap underneath is the very
                                              // fault this was meant to remove.
                                              keys: _keysUnder(layout, grid),
                                              keySize: keySize,
                                              launching: _launching,
                                              onKeyPress: (pos, press) =>
                                                  _handlePress(layout, pos, press),
                                            ),
                                            // What the PC has in front, in MANUAL mode. Auto mode
                                            // says it in the title, because there the app is why
                                            // these keys are on screen at all; a deck follows
                                            // nothing, so the phone was pressing keys at something
                                            // it could not name. Two cells wide, because an icon
                                            // and an app name at key size need the width.
                                            if (_foregroundApp(layout) case final app?)
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                width:
                                                    _panelCells(layout, grid) * keySize +
                                                    (_panelCells(layout, grid) - 1) *
                                                        KeyGrid.gapFor(keySize),
                                                height: keySize,
                                                child: _ForegroundApp(
                                                  name: app,
                                                  icon: layout.source.appIcon,
                                                  keySize: keySize,
                                                ),
                                              ),
                                            if (_swiping)
                                              for (final side in const [-1, 1])
                                                if (_neighbour(layout, side) case final near?)
                                                  Positioned(
                                                    left:
                                                        side *
                                                        (KeyGrid.widthFor(grid, keySize) +
                                                            KeyGrid.gapFor(keySize)),
                                                    top: 0,
                                                    // Not pressable: it is a page you have not
                                                    // arrived at, and a key half off the screen is
                                                    // not something anyone means to hit.
                                                    child: IgnorePointer(
                                                      child: KeyGrid(
                                                        grid: grid,
                                                        keys: near.keys,
                                                        keySize: keySize,
                                                        launching: const {},
                                                        onKeyPress: (_, _) {},
                                                      ),
                                                    ),
                                                  ),
                                          ],
                                        ),
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
    final t = AppLocalizations.of(context)!;
    final host = hostName.isEmpty ? t.yourPc : '"$hostName"';
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
              '${t.waitingForHost(host)}\n${t.waitingForHostHint}',
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
        // The one offline that waiting does not cure: this PC is serving a different certificate
        // than the one paired with. Showing the ordinary "retrying" copy for it left the user
        // waiting on a loop that can never win. The session is deliberately NOT cleared for them —
        // see `CertificateChanged` — so the way out is theirs to take, in Settings.
        if (session.identityChanged) {
          return _Banner(
            colour: const Color(DeckTokens.accent),
            text: t.identityChanged,
            action: TextButton(
              onPressed: () => showSettingsSheet(context),
              child: Text(t.settings),
            ),
          );
        }
        return _Banner(
          colour: const Color(0xFF3A3A3C),
          text: status == SessionStatus.connecting ? t.connecting : t.offlineRetrying,
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

  /// The deck picker, when there is a host with decks to pick from.
  Widget? _deckButton(BuildContext context, AppLocalizations t) =>
      (session != null && session!.decks.isNotEmpty)
      ? _StripButton(icon: Icons.dashboard, label: _deckLabel(t), onTap: () => _pickDeck(context))
      : null;

  /// Mode, then Settings — built ONCE and laid out by whichever orientation is asking.
  ///
  /// These were written out twice and had drifted: upright read Decks / Mode / Settings and
  /// sideways read Decks / Settings / Mode. Two 56×56 tiles with an icon and a word look
  /// interchangeable at a glance, so reaching for the mode toggle after rotating opened a modal
  /// sheet over the deck instead — on a pad whose whole value is muscle memory. One list means
  /// they cannot drift again.
  List<Widget> _modeAndSettings(BuildContext context, AppLocalizations t) => [
    _StripButton(
      icon: layout.mode == 'auto' ? Icons.bolt : Icons.dashboard_customize,
      label: layout.mode == 'auto' ? t.auto : t.manual,
      onTap: () => layoutSource.setMode(layout.mode == 'auto' ? 'manual' : 'auto'),
    ),
    // The cog is back, and this time it opens something. It was removed in F7 precisely because it
    // did not: a control that cannot be pressed is worse than no control.
    _StripButton(icon: Icons.settings, label: t.settings, onTap: () => showSettingsSheet(context)),
  ];

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
        spacing: 6,
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
          ?_deckButton(context, t),
          ..._modeAndSettings(context, t),
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
            ?_deckButton(context, t),
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
            ..._modeAndSettings(context, t),
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

/// What the PC has in front, in the two cells the phone reserves at the end of every page.
///
/// **Deliberately not a key.** Everything else on this surface is a cap that sinks under a finger;
/// this one does nothing when pressed, so it must not invite the press. No cap, no cast shadow, no
/// gradient — a recessed well instead, the way a readout is set into a real device rather than
/// standing proud of it.
///
/// Icon on the left with the name beside it, not stacked: a two-cell box is wide and short, and
/// laying it out sideways is what buys the icon its size.
class _ForegroundApp extends StatelessWidget {
  final String name;
  final String? icon;
  final double keySize;
  const _ForegroundApp({required this.name, required this.icon, required this.keySize});

  @override
  Widget build(BuildContext context) {
    final image = decodedIcon(icon);
    return IgnorePointer(
      child: Semantics(
        label: AppLocalizations.of(context)!.inFrontOnPc(name),
        excludeSemantics: true,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: keySize * 0.16),
          decoration: BoxDecoration(
            // Darker than the bezel it sits in, so it reads as cut INTO the device. A key is
            // lighter than its surroundings and stands on a shadow; this is the inverse of that.
            color: const Color(0x33000000),
            borderRadius: BorderRadius.circular(DeckTokens.keyCornerRadiusPx),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: Row(
            children: [
              if (image != null)
                Image(
                  image: image,
                  width: keySize * 0.52,
                  height: keySize * 0.52,
                  gaplessPlayback: true,
                )
              else
                Icon(
                  Icons.desktop_windows_outlined,
                  size: keySize * 0.44,
                  color: const Color(DeckTokens.textSecondary),
                ),
              SizedBox(width: keySize * 0.14),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(DeckTokens.textPrimary),
                    fontSize: keySize * 0.15,
                    height: 1.15,
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
