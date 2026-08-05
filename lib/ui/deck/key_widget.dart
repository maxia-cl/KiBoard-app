import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/deck.dart';
import '../icons.dart';
import '../tokens.g.dart';

Uint8List? _decodeDataUri(String? uri) {
  if (uri == null || !uri.startsWith('data:')) return null;
  final comma = uri.indexOf(',');
  if (comma == -1) return null;
  return base64Decode(uri.substring(comma + 1));
}

/// A single Stream Deck key (docs/implementation-plan.md §3.0-3.1): 1:1 LCD square, no border or
/// shadow of its own (the background *is* the key), mechanical press feel, and a long-press ring
/// that makes the second (hold) action visible before it fires.
class KeyWidget extends StatefulWidget {
  final DeckKey keyData;
  final double size;
  final void Function(String press)? onPress;

  /// Lit green because the host answered `key_result` ok (§3.1). This is the ONLY signal that the
  /// PC actually did the thing — the press animation only proves the phone felt the touch, and
  /// Elgato's number-one complaint is not knowing whether the deck is still talking to anything.
  final bool confirmed;

  /// Pressed, and the app it opens is not up yet. Painted in the brand red until the host says
  /// `state.running` — launching an app takes seconds, and without this the deck looks like it
  /// swallowed the press. The green `confirmed` flash cannot say it: that only means the PC
  /// received the press, not that anything happened.
  final bool launching;

  const KeyWidget({
    super.key,
    required this.keyData,
    required this.size,
    this.onPress,
    this.confirmed = false,
    this.launching = false,
  });

  @override
  State<KeyWidget> createState() => _KeyWidgetState();
}

class _KeyWidgetState extends State<KeyWidget> with SingleTickerProviderStateMixin {
  bool _pressed = false;

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
    final imageBytes = _decodeDataUri(key.image);

    Widget content = const SizedBox.shrink();
    if (!isEmpty) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (imageBytes != null)
            Image.memory(imageBytes, width: widget.size * 0.42, height: widget.size * 0.42)
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
    final face = widget.confirmed
        // Blended rather than solid green: the key stays recognisable while it acknowledges, which
        // matters when the confirmation is this brief.
        ? Color.lerp(baseColor, const Color(DeckTokens.stateOn), 0.55)!
        : _pressed
        ? Color.lerp(baseColor, Colors.black, DeckTokens.pressDarkenPercent / 100)!
        : baseColor;

    // The cap comes back up on the POINTER, not on the tap. With `onDoubleTap` registered the tap
    // recognizer holds its verdict for the double-press window (§3.1, 300 ms) before `onTapUp`
    // fires — so the key stayed visibly down for a third of a second after the finger left, which
    // is the one thing a physical button never does. The Listener sits outside the arena and does
    // not wait for anyone.
    return Listener(
      onPointerUp: isEmpty ? null : (_) => setState(() => _pressed = false),
      onPointerCancel: isEmpty ? null : (_) => setState(() => _pressed = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The buzz belongs to the press, not to the release: a real key answers under the finger.
        // This is also what a press that never reaches the PC still gets — the deck feeling dead on
        // a dropped link was the complaint that put the confirmation dot in §3.1.
        onTapDown: isEmpty
            ? null
            : (_) {
                HapticFeedback.selectionClick();
                setState(() => _pressed = true);
              },
        onTapCancel: isEmpty ? null : () => setState(() => _pressed = false),
        onTapUp: isEmpty
            ? null
            : (_) {
                setState(() => _pressed = false);
              },
        onTap: isEmpty ? null : () => widget.onPress?.call('short'),
        onDoubleTap: isEmpty ? null : () => widget.onPress?.call('double'),
        // Only where there IS a second action. Drawn on every key it promised one that does not
        // exist — "¿qué significa el círculo rojo?" is what a control saying nothing looks like.
        onLongPressStart: isEmpty || key.hold == null
            ? null
            : (_) => _ringController.forward(from: 0),
        onLongPress: isEmpty ? null : () => widget.onPress?.call('long'),
        onLongPressEnd: isEmpty ? null : (_) => _ringController.reset(),
        onLongPressCancel: isEmpty ? null : () => _ringController.reset(),
        child: AnimatedScale(
          scale: _pressed ? DeckTokens.pressScale : 1.0,
          duration: const Duration(milliseconds: DeckTokens.pressDurationMs),
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
                duration: Duration(milliseconds: _pressed ? 45 : 130),
                curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
                transform: Matrix4.translationValues(0, _pressed ? _travel : 0, 0),
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
                      Color.lerp(face, Colors.white, _pressed ? 0.02 : 0.10)!,
                      face,
                      Color.lerp(face, Colors.black, _pressed ? 0.14 : 0.07)!,
                    ],
                  ),
                  // Ambient occlusion rather than a drop shadow: wide, soft, pulled in by a
                  // negative spread, so the cap reads as sitting ON something instead of floating.
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _pressed ? 0.35 : 0.55),
                      blurRadius: _pressed ? 3 : 10,
                      spreadRadius: _pressed ? -3 : -2,
                      offset: Offset(0, _pressed ? 1 : 4),
                    ),
                  ],
                  // The seam where the cap meets its housing. Uniform, because Flutter cannot
                  // round a border whose sides differ — the lit top edge is the overlay below.
                  border: Border.all(color: Colors.black.withValues(alpha: _pressed ? 0.10 : 0.28)),
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
                  opacity: _pressed ? 0.15 : 1,
                  duration: Duration(milliseconds: _pressed ? 45 : 130),
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
