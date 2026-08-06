import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/deck.dart';
import '../../settings.dart';
import '../icons.dart';
import '../tokens.g.dart';

/// The same icon, decoded ONCE.
///
/// Every rebuild used to call `base64Decode` again, and a fresh `Uint8List` is a fresh
/// `MemoryImage` as far as Flutter is concerned: different provider, new decode, one frame with
/// nothing in it. That was invisible while the host only re-sent a layout when the foreground app
/// changed. Now that it re-sends whenever any app opens or closes, every icon on the page blinked
/// each time — which is what "parpadean varios iconos cuando la app se abre" was.
///
/// Keyed by the data URI itself, so an icon that really changed still gets a new provider.
///
/// ponytail: a plain map with a ceiling, cleared wholesale when it is hit. The Launcher is ~60
/// icons and they are stable; an LRU would be more code than the problem.
final Map<String, MemoryImage> _iconCache = {};
const _iconCacheLimit = 160;

MemoryImage? _iconFor(String? uri) {
  if (uri == null || !uri.startsWith('data:')) return null;
  final cached = _iconCache[uri];
  if (cached != null) return cached;
  final comma = uri.indexOf(',');
  if (comma == -1) return null;
  if (_iconCache.length >= _iconCacheLimit) _iconCache.clear();
  return _iconCache[uri] = MemoryImage(base64Decode(uri.substring(comma + 1)));
}

/// A single Stream Deck key (docs/implementation-plan.md §3.0-3.1): 1:1 LCD square, no border or
/// shadow of its own (the background *is* the key), mechanical press feel, and a long-press ring
/// that makes the second (hold) action visible before it fires.
class KeyWidget extends StatefulWidget {
  final DeckKey keyData;
  final double size;
  final void Function(String press)? onPress;

  /// Pressed, and the app it opens is not up yet — see the spinner below. Launching takes seconds,
  /// and without it the deck looks like it swallowed the press.
  final bool launching;

  const KeyWidget({
    super.key,
    required this.keyData,
    required this.size,
    this.onPress,
    this.launching = false,
  });

  @override
  State<KeyWidget> createState() => _KeyWidgetState();
}

class _KeyWidgetState extends State<KeyWidget> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  /// A key that opens an app stays DOWN when the finger leaves, instead of springing back and
  /// being pushed down again a moment later by [KeyWidget.launching].
  ///
  /// That moment is not imaginary: with `onDoubleTap` registered, `onTap` only fires once the
  /// double-press window (§3.1, 300 ms) has passed, so the press is not even sent until then. The
  /// cap popping up and sinking again inside those 300 ms is the blink.
  ///
  /// [_holdLimit] is the way out for a press the host refuses or never answers: without it a key
  /// whose launch never starts would stay down for good.
  Timer? _holdTimer;
  static const _holdLimit = Duration(milliseconds: 1500);

  bool get _opensApp => widget.keyData.running != null;

  /// Where the finger landed, and whether it has since travelled far enough to be a swipe.
  ///
  /// The deck swipes sideways to change page, and a swipe starts on a key. Buzzing and clicking on
  /// touch-down meant every page change also sounded like a press that never happened — the key
  /// correctly did nothing, and correctly said it had. Feedback belongs to the press that lands.
  Offset? _downAt;
  bool _slid = false;

  void _releaseAfterLimit() {
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdLimit, () {
      if (mounted && !widget.launching) setState(() => _pressed = false);
    });
  }

  @override
  void didUpdateWidget(KeyWidget old) {
    super.didUpdateWidget(old);
    // The wait is over — either it is launching now (which holds the cap by itself) or it stopped.
    if (old.launching != widget.launching) {
      _holdTimer?.cancel();
      if (!widget.launching && _pressed) setState(() => _pressed = false);
    }
  }

  /// How far the cap sinks, in logical pixels. Small on purpose: the travel on a real deck is
  /// about a millimetre, and a millimetre at arm's length is about this.
  static const _travel = 2.0;
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: DeckTokens.pressLongPressRingMs),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.keyData;
    final isEmpty = key.kind == KeyKind.empty;
    final baseColor = key.danger
        ? const Color(DeckTokens.keyDangerBackground)
        : key.color != null
        ? Color(key.color!)
        : isEmpty
        ? const Color(DeckTokens.keyEmptyBackground)
        : const Color(DeckTokens.keyDefaultBackground);
    final image = _iconFor(key.image);

    Widget content = const SizedBox.shrink();
    if (!isEmpty) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (image != null)
            Image(
              image: image,
              width: widget.size * 0.42,
              height: widget.size * 0.42,
              // Holds the last frame while a new provider decodes, so even a genuine icon change
              // swaps rather than blinks through empty.
              gaplessPlayback: true,
            )
          else
            Icon(
              iconFor(key.icon),
              color: const Color(DeckTokens.textPrimary),
              size: widget.size * 0.32,
            ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              key.label ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(DeckTokens.textPrimary), fontSize: 10),
            ),
          ),
          // §4.3's second line: the window's title. The host has always sent it and the model has
          // always parsed it, and nothing drew it — so the switcher listed two windows called
          // "chrome" with no way to tell which was which, which is the one job it has.
          //
          // Only `windows` keys carry it; a deck key leaves this out entirely.
          if ((key.sub ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                key.sub!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(DeckTokens.textSecondary),
                  fontSize: 8,
                  height: 1.2,
                ),
              ),
            ),
        ],
      );
    }

    // The colour of the cap itself, before the light on it. Kept out of the decoration so the
    // gradient and the shadow have one thing to shade rather than three colours to agree on.
    // The cap's own colour. A press used to blend it green when `key_result` came back ok — the
    // only proof §3.1 had that the PC did the thing — but on a surface that is meant to feel like
    // hardware the flash read as a status light nobody asked for. What acknowledges a press now is
    // the press itself: the cap goes down under the finger, the haptic fires, and a press the PC
    // REFUSES still says so out loud (the snackbar in `_handlePress`).
    // Down while the app comes up: a real button that stays in is the clearest way to say "this
    // one is working on it", and it also says the obvious thing about pressing it again.
    final down = _pressed || widget.launching;

    final face = down
        ? Color.lerp(baseColor, Colors.black, DeckTokens.pressDarkenPercent / 100)!
        : baseColor;

    // While it is launching the key answers nothing: no press, no long press, no second tap. It
    // is already doing the thing, and a deck that accepts a press it will ignore is worse than one
    // that says it is busy.
    final deaf = isEmpty || widget.launching;

    return Listener(
      // DOWN on the pointer, not on the tap. With `onDoubleTap` registered the tap recognizer
      // waits for the arena before it says anything — measured at ~100 ms here — and a key pad
      // that answers a tenth of a second late feels broken even when it works.
      // DOWN on the pointer, not on the tap. With `onDoubleTap` registered the tap recognizer
      // waits for the arena before it says anything — measured at about 100 ms — and a key pad
      // that answers a tenth of a second late feels broken even when it works. The cap moving is
      // safe to show at once; it costs nothing if the touch turns out to be a swipe.
      onPointerDown: deaf
          ? null
          : (e) {
              _downAt = e.position;
              _slid = false;
              setState(() => _pressed = true);
            },
      onPointerMove: deaf
          ? null
          : (e) {
              if (_slid || _downAt == null) return;
              if ((e.position - _downAt!).distance <= kTouchSlop) return;
              // Far enough to be the page swipe. The key gives up now, silently.
              _slid = true;
              setState(() => _pressed = false);
            },
      onPointerUp: deaf
          ? null
          : (_) {
              if (_slid) return; // it was a swipe; nothing was pressed
              // The click and the buzz land HERE, on a press that actually happened.
              final prefs = Settings.instance.value;
              if (prefs.haptics) HapticFeedback.selectionClick();
              if (prefs.sound) SystemSound.play(SystemSoundType.click);
              if (_opensApp) {
                _releaseAfterLimit(); // stays down until the launch takes over
              } else {
                setState(() => _pressed = false);
              }
            },
      onPointerCancel: deaf ? null : (_) => setState(() => _pressed = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The buzz belongs to the press, not to the release: a real key answers under the finger.
        // This is also what a press that never reaches the PC still gets — the deck feeling dead on
        // a dropped link was the complaint that put the confirmation dot in §3.1.
        onTapCancel: deaf ? null : () => setState(() => _pressed = false),
        onTap: deaf ? null : () => widget.onPress?.call('short'),
        onDoubleTap: deaf ? null : () => widget.onPress?.call('double'),
        // Only where there IS a second action. Drawn on every key it promised one that does not
        // exist — "¿qué significa el círculo rojo?" is what a control saying nothing looks like.
        onLongPressStart: deaf || key.hold == null ? null : (_) => _ringController.forward(from: 0),
        onLongPress: deaf ? null : () => widget.onPress?.call('long'),
        onLongPressEnd: deaf ? null : (_) => _ringController.reset(),
        onLongPressCancel: deaf ? null : () => _ringController.reset(),
        child: AnimatedScale(
          // Barely there: the old 0.96 shrank the whole cap, which reads as a card being tapped.
          // A key pushed straight down only loses a hair of width to perspective.
          scale: down ? 0.985 : 1.0,
          // Asymmetric — a real key gives way at once and springs back.
          duration: Duration(milliseconds: down ? 45 : 130),
          curve: down ? Curves.easeOut : Curves.easeOutBack,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // A key cap, not a coloured square. What reads as "physical" is three things
              // agreeing: the light always comes from ABOVE (a gradient that flips reads as a
              // different material, not as a pressed key), the cap stands on an ambient shadow,
              // and pressing it moves the cap DOWN into that shadow instead of merely darkening.
              AnimatedContainer(
                // Asymmetric on purpose: a real key gives way at once and springs back. Equal
                // timings in both directions are the tell of a software button.
                duration: Duration(milliseconds: down ? 45 : 130),
                curve: down ? Curves.easeOut : Curves.easeOutBack,
                transform: Matrix4.translationValues(0, down ? _travel : 0, 0),
                transformAlignment: Alignment.center,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DeckTokens.keyCornerRadiusPx),
                  // Three stops, not two: a moulded cap is brightest just under its top edge, the
                  // way it catches a ceiling light, and falls off towards the base.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.55, 1],
                    colors: [
                      Color.lerp(face, Colors.white, down ? 0.02 : 0.10)!,
                      face,
                      Color.lerp(face, Colors.black, down ? 0.14 : 0.07)!,
                    ],
                  ),
                  // Ambient occlusion rather than a drop shadow: wide, soft, pulled in by a
                  // negative spread, so the cap reads as sitting ON something instead of floating.
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: down ? 0.35 : 0.55),
                      blurRadius: down ? 3 : 10,
                      spreadRadius: down ? -3 : -2,
                      offset: Offset(0, down ? 1 : 4),
                    ),
                  ],
                  // The seam where the cap meets its housing. Uniform, because Flutter cannot
                  // round a border whose sides differ — the lit top edge is the overlay below.
                  border: Border.all(color: Colors.black.withValues(alpha: down ? 0.10 : 0.28)),
                ),
                child: content,
              ),
              if (key.stateOn)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(DeckTokens.stateOn),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              if (key.current)
                Positioned(
                  left: 2,
                  top: 8,
                  bottom: 8,
                  child: Container(width: 3, color: const Color(DeckTokens.accent)),
                ),
              if (key.minimized)
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(DeckTokens.keyCornerRadiusPx),
                  ),
                ),
              // The moulding: the top edge catches the light, and only the top. It fades as the
              // cap goes down, because a key level with its housing has no edge left to catch
              // anything — that fade is half of what sells the travel.
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: down ? 0.15 : 1,
                  duration: Duration(milliseconds: down ? 45 : 130),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(DeckTokens.keyCornerRadiusPx),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.06],
                        colors: [Colors.white.withValues(alpha: 0.16), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
              // Opening an app takes seconds, and the deck has to say so with the vocabulary
              // everyone already knows: a spinner. Colouring the key instead said "something is
              // wrong with this key" — red is what a danger key is painted, and this is not that.
              // The face dims so the spinner is the thing being read.
              if (widget.launching) ...[
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(DeckTokens.keyCornerRadiusPx),
                  ),
                ),
                SizedBox(
                  width: widget.size * 0.34,
                  height: widget.size * 0.34,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(DeckTokens.textPrimary),
                  ),
                ),
              ],
              AnimatedBuilder(
                animation: _ringController,
                builder: (context, _) {
                  if (_ringController.value == 0) return const SizedBox.shrink();
                  return SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: CircularProgressIndicator(
                        value: _ringController.value,
                        strokeWidth: 3,
                        color: const Color(DeckTokens.accent),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
