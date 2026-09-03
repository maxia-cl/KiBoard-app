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

  const DeckScreen({
    super.key,
    required this.layoutSource,
    required this.hostName,
    this.session,
  });

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen>
    with SingleTickerProviderStateMixin {
  late final Stream<Layout> _layouts = widget.layoutSource.layouts();

  /// Watches for the app coming back to the foreground. The phone spends most of its life in a
  /// pocket while the PC sleeps, so `resumed` is the single most frequent transition in the
  /// product — and the moment the user has just woken the PC and wants to press a key.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => widget.session?.reconnectNow(),
  );

  StreamSubscription<String>? _toasts;
  StreamSubscription<bool>? _manualFeatures;

  @override
  void initState() {
    super.initState();
    _pageMotion = AnimationController.unbounded(vsync: this);
    _lifecycle; // created lazily; touch it so it is listening from the first frame
    // §4.4. The host was talking and nothing was listening: every `toast` it sent was filtered
    // out and dropped, which is why "Profile imported" never appeared anywhere.
    _toasts = widget.layoutSource.toasts().listen((text) {
      if (mounted) _showKeyError(text);
    });
    _manualFeatures = widget.layoutSource.manualFeature().listen((_) {
      if (mounted) setState(() {});
    });
    // A key pad you have to wake up first is not a key pad. Android's screen timeout is ~30s, and
    // the deck's whole point is being glanceable and pressable without ceremony while you work on
    // the PC. Released in dispose, so it only applies while the deck is actually on screen.
    unawaited(
      WakelockPlus.enable().catchError((Object error, StackTrace stackTrace) {
        trace('wakelock unavailable: $error');
      }),
    );
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
    _pageMotion.dispose();
    _preloads?.cancel();
    _toasts?.cancel();
    _manualFeatures?.cancel();
    _exitArmed?.cancel();
    _lifecycle.dispose();
    unawaited(
      WakelockPlus.disable().catchError((Object error, StackTrace stackTrace) {
        trace('wakelock release unavailable: $error');
      }),
    );
    super.dispose();
  }

  double? _lastTracedSize;

  /// Reports the sizing decision when it changes. The point of `sizeForDevice` is that the key
  /// does NOT resize on rotation, and eyeballing a screenshot cannot tell 118 from 120 — if the
  /// box cap (`byBox`) is ever the one chosen, the guarantee is broken and this says so.
  void _traceSize(
    double byDevice,
    double byBox,
    double chosen,
    double w,
    double h,
  ) {
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
    if (mounted && _launching.contains(pos)) {
      setState(() => _launching.remove(pos));
    }
  }

  /// Ends the wait early for keys whose app the host now reports as up. Called on every layout,
  /// since that is when the answer arrives.
  void _clearLaunched(Layout layout) {
    if (_launching.isEmpty) return;
    final done = _launching
        .where(
          (pos) =>
              pos >= layout.keys.length || layout.keys[pos].running == true,
        )
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
  /// own page transitions sit around 300 ms; a control surface wants to feel nearly immediate.
  static const _pageSlide = Duration(milliseconds: 120);

  /// Identity of what is on screen. The deck as well as the page, so switching decks also swaps
  /// rather than mutating the same grid under the user.
  String _pageKey(Layout layout) =>
      '${layout.mode}/${layout.source.id}#${layout.page}';

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
      //
      // Everything EXCEPT the new surface's own pages. The host sends a layout and its `page_preload`
      // neighbours back to back, and all of them are read off the socket before this build runs —
      // so clearing outright threw away the pages that had just arrived for the app being switched
      // to, and the first swipe after every app change had nothing to draw.
      _seen.removeWhere((key, _) => !key.startsWith('$source/'));
      // A different deck, or auto mode following a different app. Not a swipe, so there is no
      // direction to infer; leave the last one alone.
      _lastSource = source;
      _lastPage = layout.page;
      _pendingPage = null;
      _handoffPage = null;
      return;
    }
    if (layout.page != _lastPage) {
      _pageDir = layout.page > _lastPage ? 1 : -1;
      _lastPage = layout.page;
      // The page the swipe asked for has arrived. This runs during build, so it lands on the
      // INCOMING subtree only — the outgoing one keeps the offset it was last built with and
      // carries on out from there, which is what makes the swap continue the gesture instead of
      // starting a second, separate move.
      if (_pendingPage == layout.page) {
        // The neighbour already visible under the finger IS this layout. Suppress the switcher's
        // second slide and keep using the same motion value, translated onto the incoming page.
        // That makes the host confirmation a zero-pixel handoff instead of a visible restart.
        _swipeGuard?.cancel();
        _handoffPage = layout.page;
        if (!_pageMotion.isAnimating) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _finishHandoff());
        }
      } else {
        _pendingPage = null;
        _handoffPage = null;
        _pageMotion.stop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pageMotion.value = 0;
        });
      }
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

  /// Whether the foreground-app panel sits on the FIRST row instead of the last.
  ///
  /// Upright only, and off by default. Held one-handed, the bottom of a phone is the only part a
  /// thumb reaches — so moving the panel up hands that row back to the keys. Sideways the whole pad
  /// is within reach and the panel stays where it is, which also keeps the reserved cells in the
  /// corner the eye already goes to.
  bool _panelOnTop(bool sideways) =>
      !sideways && Settings.instance.value.appPanelAtTop;

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

  /// Where the page sits relative to home, in pixels. Unbounded because it follows a finger rather
  /// than a 0..1 timeline. Only the transform listens: pointer packets never rebuild the grids.
  late final AnimationController _pageMotion;

  /// A committed local change waiting for the host's layout, plus the geometry needed to turn the
  /// already-visible neighbour into that incoming layout without moving it by even one pixel.
  int? _pendingPage;
  int? _handoffPage;
  int _pendingDir = 0;
  double _pageExtent = 0;

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
  String _seenKey(Layout l, int page) =>
      '${l.mode}/${l.source.id}/${l.grid.capacity}#$page';

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
  static const _settle = Duration(milliseconds: 110);

  /// A host that has not answered by now is asleep, not slow — the deck stays up while offline
  /// (that is what the link banner is for), so the page has to come back rather than hang off
  /// the edge of the screen.
  static const _swipeTimeout = Duration(milliseconds: 600);

  void _dragUpdate(Layout layout, double delta) {
    if (_pendingPage != null) return;
    // Resistance at the two ends, the way a list rubber-bands: it still moves, so the gesture is
    // never dead under the finger, but it says there is nothing over there.
    final pushingPastEnd =
        (delta < 0 && layout.page >= layout.pages - 1) ||
        (delta > 0 && layout.page <= 0);
    // The first packet adds the neighbours once. Every packet after it only updates the composited
    // transform below; rebuilding all of the keys here was the source of the sticky swipe.
    if (!_dragging) {
      setState(() {
        _dragging = true;
        _swiping = true;
      });
    }
    _pageMotion.value += pushingPastEnd ? delta * 0.25 : delta;
  }

  void _dragCancel() {
    if (_pendingPage != null) return;
    setState(() => _dragging = false);
    _pageMotion
        .animateTo(0, duration: _settle, curve: Curves.easeOutCubic)
        .whenComplete(() {
          if (mounted && _pendingPage == null && _pageMotion.value == 0) {
            setState(() => _swiping = false);
          }
        });
  }

  void _dragEnd(Layout layout, double velocity, double width, double extent) {
    final dx = _pageMotion.value;
    // Either a long drag or a quick flick commits. Distance is the half that was missing — a slow,
    // deliberate drag across the whole pad ends at zero velocity and used to change nothing.
    final far = dx.abs() > width * 0.18;
    final fast = velocity.abs() > 260;
    final dir = (dx != 0 ? dx < 0 : velocity < 0) ? 1 : -1;
    final next = (layout.page + dir).clamp(0, layout.pages - 1);

    if (layout.pages < 2 || !(far || fast) || next == layout.page) {
      setState(() => _dragging = false);
      _pageMotion
          .animateTo(0, duration: _settle, curve: Curves.easeOutCubic)
          .whenComplete(() {
            if (mounted && _pendingPage == null && _pageMotion.value == 0) {
              setState(() => _swiping = false);
            }
          });
      return;
    }

    if (Settings.instance.value.haptics) HapticFeedback.selectionClick();
    trace('swipe -> page $next of ${layout.pages}');
    // Keep going the way the finger was going. The swap catches it part way out, and the outgoing
    // page keeps this offset because it is the widget that was already built — only the incoming
    // one is rebuilt, at zero.
    setState(() {
      _dragging = false;
      _pendingPage = next;
      _pendingDir = dir;
      _pageExtent = extent;
    });
    _pageMotion
        .animateTo(-dir * extent, duration: _settle, curve: Curves.easeOutCubic)
        .whenComplete(_finishHandoff);
    _swipeGuard?.cancel();
    _swipeGuard = Timer(_swipeTimeout, () {
      if (!mounted || _pendingPage == null) return;
      trace('no layout for the swipe — putting the page back');
      setState(() {
        _pendingPage = null;
        _handoffPage = null;
      });
      _pageMotion
          .animateTo(0, duration: _settle, curve: Curves.easeOutCubic)
          .whenComplete(() {
            if (mounted && _pageMotion.value == 0) {
              setState(() => _swiping = false);
            }
          });
    });
    widget.session?.setPage(next);
  }

  /// Completes the local/remote handoff after both halves are ready: the motion has reached the
  /// centre and the host has confirmed the page. Either may arrive first; the visible result is the
  /// same because [_handoffOffset] maps both layouts onto the same physical position.
  void _finishHandoff() {
    if (!mounted || _handoffPage == null || _pageMotion.isAnimating) return;
    _handoffPage = null;
    _pendingPage = null;
    _pageMotion.value = 0;
    setState(() => _swiping = false);
  }

  double _handoffOffset(Layout layout) =>
      _pageMotion.value +
      (_handoffPage == layout.page ? _pendingDir * _pageExtent : 0);

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
        backgroundColor: const Color(DeckTokens.surface),
        title: Text(
          '$label?',
          style: const TextStyle(color: Color(DeckTokens.textPrimary)),
        ),
        content: Text(
          t.cannotUndo,
          style: TextStyle(color: Color(DeckTokens.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              t.cancel,
              style: TextStyle(color: Color(DeckTokens.textSecondary)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(DeckTokens.accent),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(label),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  Future<void> _closeForegroundApp(Layout layout) async {
    final app = _foregroundApp(layout);
    if (app == null) return;
    final t = AppLocalizations.of(context)!;
    final live = widget.session;
    if (live != null && live.currentStatus != SessionStatus.online) {
      _showKeyError(t.noAnswer);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(DeckTokens.surface),
        title: Text(
          '${t.closeApp(app)}?',
          style: const TextStyle(color: Color(DeckTokens.textPrimary)),
        ),
        content: Text(
          t.cannotUndo,
          style: const TextStyle(color: Color(DeckTokens.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              t.cancel,
              style: const TextStyle(color: Color(DeckTokens.textSecondary)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.close),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (Settings.instance.value.haptics) HapticFeedback.mediumImpact();
    await widget.layoutSource.closeForegroundApp();
  }

  Future<void> _openWindowSwitcher() async {
    final live = widget.session;
    if (live != null && live.currentStatus != SessionStatus.online) {
      _showKeyError(AppLocalizations.of(context)!.windowsFailed);
      return;
    }
    await Navigator.of(context).push(
      screenRoute(WindowSwitcherScreen(layoutSource: widget.layoutSource)),
    );
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

    // §4.2: a key that asks something first. The whole action string is in the layout, so the list
    // is drawn HERE — and what goes back is the index or the text, never the action.
    // Dismissing is not a press: nothing is sent, exactly like cancelling a danger key.
    int? option;
    String? typed;
    final action = key.action ?? '';
    if (action.startsWith('picker:') || action.startsWith('colorpicker:')) {
      option = await _chooseOption(key, action);
      if (option == null || !mounted) return;
    } else if (action.startsWith('prompt:')) {
      typed = await _askForText(action);
      if (typed == null || !mounted) return;
    }

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
      Navigator.of(context).push(
        screenRoute(WindowSwitcherScreen(layoutSource: widget.layoutSource)),
      );
      return;
    }

    final session = widget.session;

    // §4.2.1: these name a screen on THIS phone, not work for the PC. Opening it is the whole
    // action — the press is never sent, and what reaches the host afterwards is `input`.
    if (session != null &&
        (key.action == 'trackpad' || key.action == 'dictate')) {
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
      widget.layoutSource.pressKey(
        pos: pos,
        press: press,
        option: option,
        text: typed,
      );
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
      final result = await session.pressResult(
        pos: pos,
        press: press,
        option: option,
        text: typed,
      );
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

  /// `Name=value;Name2=value2` — the options of a `picker:` or `colorpicker:`, in the order the
  /// host wrote them, which is the order `option` counts in. Split on the FIRST `=`: a picker's
  /// value is a whole action chain and carries plenty more.
  List<(String, String)> _branches(String list) => [
    for (final part in list.split(';'))
      if (part.split('=') case [final name, ...final rest] when rest.isNotEmpty)
        (name.trim(), rest.join('=')),
  ];

  /// The list a `picker:`/`colorpicker:` key puts up, returning the index chosen — or null when it
  /// was dismissed, which is not a press.
  ///
  /// A colour swatch shows its own colour: the hex in the action exists for exactly that, and the
  /// host runs the palette entry by NAME rather than by the value drawn here.
  Future<int?> _chooseOption(DeckKey key, String action) async {
    final colours = action.startsWith('colorpicker:');
    final options = _branches(action.substring(action.indexOf(':') + 1));
    if (options.isEmpty) return null;
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(DeckTokens.surface),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if ((key.label ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  key.label!,
                  style: TextStyle(
                    color: Color(DeckTokens.textSecondary),
                    fontSize: 13,
                  ),
                ),
              ),
            for (final (i, (name, value)) in options.indexed)
              ListTile(
                leading: colours
                    ? Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(
                            0xFF000000 |
                                (int.tryParse(value.trim(), radix: 16) ?? 0),
                          ),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                      )
                    : null,
                title: Text(
                  name,
                  style: const TextStyle(color: Color(DeckTokens.textPrimary)),
                ),
                onTap: () => Navigator.of(sheetContext).pop(i),
              ),
          ],
        ),
      ),
    );
  }

  /// The text field a `prompt:` key puts up, returning what was typed — or null when it was
  /// cancelled or left empty. The label is the host's; the text goes in the hole of ITS template.
  Future<String?> _askForText(String action) async {
    final t = AppLocalizations.of(context)!;
    final label = action.substring('prompt:'.length).split('=').first.trim();
    // No controller: the dialog's exit animation rebuilds the field one more time, and a controller
    // disposed on the way out is used after being disposed. The value is all this needs.
    var value = '';
    final answer = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(DeckTokens.surface),
        title: Text(
          label,
          style: const TextStyle(color: Color(DeckTokens.textPrimary)),
        ),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: Color(DeckTokens.textPrimary)),
          onChanged: (typed) => value = typed,
          onSubmitted: (typed) => Navigator.of(dialogContext).pop(typed),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(value),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    return (answer == null || answer.trim().isEmpty) ? null : answer;
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
          backgroundColor: const Color(DeckTokens.surfaceRaised),
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
      // Rebuilds when Settings change, which no other screen needs: haptics and sound are read at
      // the moment of a press, but the panel's position is LAYOUT — chosen in a sheet over this
      // very deck, so it has to be true the moment the sheet closes.
      child: ValueListenableBuilder<SettingsData>(
        valueListenable: Settings.instance,
        builder: (context, _, _) => _buildDeck(context),
      ),
    );
  }

  Widget _buildDeck(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(DeckTokens.appBackground),
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
                  if (widget.session != null)
                    _LinkBanner(session: widget.session!),
                  Expanded(
                    child: _NoLayoutYet(
                      session: widget.session,
                      hostName: widget.hostName,
                    ),
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
            final sideways =
                MediaQuery.sizeOf(context).width >
                MediaQuery.sizeOf(context).height;
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
                if (widget.session != null)
                  _LinkBanner(session: widget.session!),
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
                        final w =
                            constraints.maxWidth - DeviceBezel.chromeWidth();
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
                        final byDevice = KeyGrid.sizeForDevice(
                          MediaQuery.sizeOf(context),
                          grid,
                        );
                        final byBox = KeyGrid.sizeToFit(grid, w, h);
                        // 2% off the key, given to the top edge of the frame below. The pad was
                        // sitting hard against the top of the device and the gap reads as breathing
                        // room around a real one.
                        final keySize = math.min(byDevice, byBox) * 0.98;
                        _traceSize(byDevice, byBox, keySize, w, h);
                        _traceShape(layout, grid);
                        final panelOnTop = _panelOnTop(sideways);
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
                            value: layout.pages > 1
                                ? '${layout.page + 1}/${layout.pages}'
                                : null,
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
                              onHorizontalDragUpdate: (d) =>
                                  _dragUpdate(layout, d.delta.dx),
                              onHorizontalDragEnd: (d) => _dragEnd(
                                layout,
                                d.primaryVelocity ?? 0,
                                KeyGrid.widthFor(grid, keySize),
                                KeyGrid.widthFor(grid, keySize) +
                                    KeyGrid.gapFor(keySize),
                              ),
                              onHorizontalDragCancel: _dragCancel,
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
                                    // A gesture handoff gets a fresh switcher. Otherwise its old
                                    // page remains in the switcher's private outgoing list and can
                                    // reappear for one frame when the zero-duration handoff ends.
                                    key: ValueKey(
                                      _handoffPage == layout.page
                                          ? 'gesture-handoff'
                                          : 'page-transition',
                                    ),
                                    duration: _handoffPage == layout.page
                                        ? Duration.zero
                                        : _pageSlide,
                                    switchInCurve: Curves.easeOutQuart,
                                    switchOutCurve: Curves.easeOutQuart,
                                    // Stacked rather than the default cross-fade-in-place: the two
                                    // pages have to pass each other, so both must be laid out.
                                    layoutBuilder: (current, previous) {
                                      // During a gesture handoff the old tree already contains the
                                      // incoming page as its neighbour. Keeping that tree for even
                                      // one zero-duration frame draws the same page twice and is the
                                      // small flash visible on the phone.
                                      if (_handoffPage == layout.page) {
                                        return current ??
                                            const SizedBox.shrink();
                                      }
                                      return Stack(
                                        alignment: Alignment.center,
                                        children: [...previous, ?current],
                                      );
                                    },
                                    transitionBuilder: (child, animation) {
                                      // The outgoing child runs this same animation in REVERSE, so
                                      // giving it the opposite start sends it out the far side while
                                      // the new one comes in from the near one.
                                      final incoming =
                                          (child.key as ValueKey<String>)
                                              .value ==
                                          _pageKey(layout);
                                      final from = Offset(
                                        incoming ? _pageDir : -_pageDir,
                                        0,
                                      );
                                      return SlideTransition(
                                        position: Tween(
                                          begin: from,
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      );
                                    },
                                    // The key is on the wrapper, not on the grid: the offset has to
                                    // belong to the page, so that the outgoing one keeps it.
                                    child: KeyedSubtree(
                                      key: ValueKey(_pageKey(layout)),
                                      // Zero duration while the finger is down, so the page IS the
                                      // finger; `_settle` once it lifts, to spring home or to carry
                                      // a committed page the rest of the way out. The controller is
                                      // unbounded because its value is a physical pixel offset.
                                      child: AnimatedBuilder(
                                        animation: _pageMotion,
                                        builder: (context, child) =>
                                            Transform.translate(
                                              offset: Offset(
                                                _handoffOffset(layout),
                                                0,
                                              ),
                                              child: child,
                                            ),
                                        // The neighbours ride INSIDE the same transform, one page
                                        // plus a gap out on either side, so they come in behind the
                                        // finger without any second animation to keep in step.
                                        // `Positioned` keeps them out of the Stack's sizing and the
                                        // ClipRect above cuts them at the edge of the device.
                                        child: RepaintBoundary(
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              KeyGrid(
                                                grid: grid,
                                                // Stops where the panel starts. Absorbing a cell and
                                                // then still drawing its cap underneath is the very
                                                // fault this was meant to remove.
                                                keys: layout.keys,
                                                keySize: keySize,
                                                launching: _launching,
                                                // Panel on the first row: the keys start after it,
                                                // so the grid opens with that many blank cells.
                                                leadingBlanks: panelOnTop
                                                    ? reservedCells
                                                    : 0,
                                                onKeyPress: (pos, press) =>
                                                    _handlePress(
                                                      layout,
                                                      pos,
                                                      press,
                                                    ),
                                              ),
                                              // What the PC has in front. The cells are reserved
                                              // (§4.1), so this never fights a key for them — and
                                              // upright the user can move it to the first row, which
                                              // hands the thumb's row back to the keys.
                                              if (_foregroundApp(layout)
                                                  case final app?)
                                                Positioned(
                                                  left: panelOnTop ? 0 : null,
                                                  right: panelOnTop ? null : 0,
                                                  top: panelOnTop ? 0 : null,
                                                  bottom: panelOnTop ? null : 0,
                                                  width:
                                                      reservedCells * keySize +
                                                      (reservedCells - 1) *
                                                          KeyGrid.gapFor(
                                                            keySize,
                                                          ),
                                                  height: keySize,
                                                  child: _ForegroundApp(
                                                    name: app,
                                                    icon: layout.source.appIcon,
                                                    keySize: keySize,
                                                    onOpen: _openWindowSwitcher,
                                                    onClose: () =>
                                                        _closeForegroundApp(
                                                          layout,
                                                        ),
                                                  ),
                                                ),
                                              if (_swiping)
                                                for (final side in const [
                                                  -1,
                                                  1,
                                                ])
                                                  if (_neighbour(layout, side)
                                                      case final near?)
                                                    Positioned(
                                                      left:
                                                          side *
                                                          (KeyGrid.widthFor(
                                                                grid,
                                                                keySize,
                                                              ) +
                                                              KeyGrid.gapFor(
                                                                keySize,
                                                              )),
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
      return const Center(
        child: CircularProgressIndicator(color: Color(DeckTokens.accent)),
      );
    }
    return StreamBuilder<SessionStatus>(
      stream: session!.status,
      initialData: session!.currentStatus,
      builder: (context, snapshot) {
        // Only spin while the link is actually up and the first layout is in flight — that is a
        // moment. Retrying cycles connecting/offline every few seconds, and spinning through that
        // would hide the explanation behind an animation for as long as the PC stays asleep.
        if (snapshot.data == SessionStatus.online) {
          return const Center(
            child: CircularProgressIndicator(color: Color(DeckTokens.accent)),
          );
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              '${t.waitingForHost(host)}\n${t.waitingForHostHint}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(DeckTokens.textSecondary),
                height: 1.5,
              ),
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
                Navigator.of(
                  context,
                ).pushReplacement(fadeRoute(DiscoverScreen()));
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
              onPressed: () =>
                  showSettingsSheet(context, layoutSource: session),
              child: Text(t.settings),
            ),
          );
        }
        return _Banner(
          colour: const Color(DeckTokens.surfaceBorder),
          text: status == SessionStatus.connecting
              ? t.connecting
              : t.offlineRetrying,
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

  /// The live session, when there is one. Connection state still belongs here; deck navigation is
  /// exposed by [layoutSource] so fixture-backed previews can render the real top bar as well.
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

  bool get _launcherActive =>
      layout.mode == 'manual' && layout.source.id == 'launcher';

  /// Launcher is an automatic, host-generated view. It only reuses the manual wire format, so
  /// it must never make the user-facing mode control look like fixed Manual mode is active.
  bool get _manualActive => layout.mode == 'manual' && !_launcherActive;

  /// Only these decks belong to Manual and can be edited in the Windows app. Launcher shares the
  /// deck wire format, but it is generated by the host from recent applications and must not leak
  /// into a picker that promises user-editable content.
  List<DeckSummary> get _availableDecks => layoutSource.decks.isNotEmpty
      ? layoutSource.decks
      : (session?.decks ?? const []);

  List<DeckSummary> _editableDecks() => _availableDecks
      .where((deck) => deck.id != 'launcher')
      .toList(growable: false);

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
    final decks = _editableDecks();
    if (decks.isEmpty) return;
    final current = layout.mode == 'manual' ? layout.source.id : null;

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(DeckTokens.surface),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final deck in decks)
                ListTile(
                  leading: Icon(
                    iconForDeck(deck.icon),
                    color: Color(
                      deck.id == current
                          ? DeckTokens.accent
                          : DeckTokens.textSecondary,
                    ),
                  ),
                  title: Text(
                    deck.name,
                    style: TextStyle(
                      color: Color(
                        deck.id == current
                            ? DeckTokens.accent
                            : DeckTokens.textPrimary,
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
    if (chosen != null) {
      await layoutSource.setMode('manual', deckId: chosen);
    }
  }

  /// Launcher is generated and ordered by the host, so it always has a direct entry point. Once a
  /// fixed Manual deck is active this same slot names it and opens the full deck picker.
  Widget? _deckButton(BuildContext context, AppLocalizations t) {
    final decks = _availableDecks;
    if (decks.isEmpty) return null;
    final launcher = decks.where((d) => d.id == 'launcher').firstOrNull;
    if (layoutSource.manualEnabled && (_manualActive || launcher == null)) {
      return _StripButton(
        icon: Icons.dashboard,
        label: _deckLabel(t),
        onTap: () => _pickDeck(context),
      );
    }
    if (launcher == null) return null;
    return _StripButton(
      icon: iconForDeck(launcher.icon),
      label: launcher.name,
      foreground: _launcherActive ? const Color(DeckTokens.accent) : null,
      onTap: () => _launcherActive
          ? layoutSource.setMode('auto')
          : layoutSource.setMode('manual', deckId: launcher.id),
    );
  }

  /// Mode, then Settings — built ONCE and laid out by whichever orientation is asking.
  ///
  /// These were written out twice and had drifted: upright read Decks / Mode / Settings and
  /// sideways read Decks / Settings / Mode. Two 56×56 tiles with an icon and a word look
  /// interchangeable at a glance, so reaching for the mode toggle after rotating opened a modal
  /// sheet over the deck instead — on a pad whose whole value is muscle memory. One list means
  /// they cannot drift again.
  List<Widget> _modeAndSettings(BuildContext context, AppLocalizations t) => [
    if (layoutSource.manualEnabled)
      _StripButton(
        icon: _manualActive ? Icons.dashboard_customize : Icons.bolt,
        label: _manualActive ? t.manual : t.auto,
        foreground: _manualActive ? const Color(DeckTokens.manualActive) : null,
        onTap: () {
          if (_manualActive) {
            layoutSource.setMode('auto');
            return;
          }
          final fixedDeck = session == null
              ? null
              : _editableDecks().firstOrNull;
          if (fixedDeck != null) {
            layoutSource.setMode('manual', deckId: fixedDeck.id);
          }
        },
      ),
    // The cog is back, and this time it opens something. It was removed in F7 precisely because it
    // did not: a control that cannot be pressed is worse than no control.
    _StripButton(
      icon: Icons.settings,
      label: t.settings,
      onTap: () => showSettingsSheet(context, layoutSource: layoutSource),
    ),
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
            _manualActive ? Icons.dashboard_customize : Icons.bolt,
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
  final Color? foreground;

  const _StripButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.foreground,
  });

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
                Icon(
                  icon,
                  color: foreground ?? const Color(DeckTokens.textPrimary),
                  size: 20,
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          foreground ?? const Color(DeckTokens.textSecondary),
                      fontSize: 10,
                    ),
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
/// **Deliberately not a key.** The identity area opens the window switcher while its explicit red
/// close affordance remains a separate action. No cap, no cast shadow, no gradient — a recessed
/// well, with both app-level actions attached to the app they actually affect.
///
/// Icon on the left with the name beside it, not stacked: a two-cell box is wide and short, and
/// laying it out sideways is what buys the icon its size.
class _ForegroundApp extends StatelessWidget {
  final String name;
  final String? icon;
  final double keySize;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  const _ForegroundApp({
    required this.name,
    required this.icon,
    required this.keySize,
    required this.onOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final image = decodedIcon(icon);
    final t = AppLocalizations.of(context)!;
    return Container(
      key: const ValueKey('foreground-app-panel'),
      padding: EdgeInsets.only(left: keySize * 0.06, right: keySize * 0.06),
      decoration: BoxDecoration(
        // Darker than the bezel it sits in, so it reads as cut INTO the device. A key is
        // lighter than its surroundings and stands on a shadow; this is the inverse of that.
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(DeckTokens.keyCornerRadiusPx),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: t.openWindows,
              child: Semantics(
                button: true,
                label: '${t.openWindows}: ${t.inFrontOnPc(name)}',
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onOpen,
                    borderRadius: BorderRadius.circular(
                      DeckTokens.keyCornerRadiusPx,
                    ),
                    child: SizedBox.expand(
                      child: Row(
                        children: [
                          SizedBox(width: keySize * 0.10),
                          if (image != null)
                            Image(
                              image: image,
                              width: keySize * 0.52,
                              height: keySize * 0.52,
                              gaplessPlayback: true,
                            )
                          else
                            Icon(
                              Icons.desktop_windows,
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
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: t.closeApp(name),
            color: const Color(DeckTokens.keyDangerBackground),
            iconSize: keySize * 0.25,
            constraints: BoxConstraints.tightFor(
              width: math.max(48.0, keySize * 0.48),
              height: math.max(48.0, keySize * 0.48),
            ),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
