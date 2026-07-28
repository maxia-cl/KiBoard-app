import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

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

  const KeyWidget({
    super.key,
    required this.keyData,
    required this.size,
    this.onPress,
    this.confirmed = false,
  });

  @override
  State<KeyWidget> createState() => _KeyWidgetState();
}

class _KeyWidgetState extends State<KeyWidget> with SingleTickerProviderStateMixin {
  bool _pressed = false;
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
            Icon(iconFor(key.icon), color: const Color(DeckTokens.textPrimary), size: widget.size * 0.32),
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
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: isEmpty ? null : (_) => setState(() => _pressed = true),
      onTapCancel: isEmpty ? null : () => setState(() => _pressed = false),
      onTapUp: isEmpty
          ? null
          : (_) {
              setState(() => _pressed = false);
            },
      onTap: isEmpty ? null : () => widget.onPress?.call('short'),
      onDoubleTap: isEmpty ? null : () => widget.onPress?.call('double'),
      onLongPressStart: isEmpty ? null : (_) => _ringController.forward(from: 0),
      onLongPress: isEmpty ? null : () => widget.onPress?.call('long'),
      onLongPressEnd: isEmpty ? null : (_) => _ringController.reset(),
      onLongPressCancel: isEmpty ? null : () => _ringController.reset(),
      child: AnimatedScale(
        scale: _pressed ? DeckTokens.pressScale : 1.0,
        duration: const Duration(milliseconds: DeckTokens.pressDurationMs),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: DeckTokens.pressDurationMs),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.confirmed
                    // Blended rather than solid green: the key stays recognisable while it
                    // acknowledges, which matters when the confirmation is this brief.
                    ? Color.lerp(baseColor, const Color(DeckTokens.stateOn), 0.55)
                    : _pressed
                    ? Color.lerp(baseColor, Colors.black, DeckTokens.pressDarkenPercent / 100)
                    : baseColor,
                borderRadius: BorderRadius.circular(DeckTokens.keyCornerRadiusPx),
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
                  decoration: const BoxDecoration(color: Color(DeckTokens.stateOn), shape: BoxShape.circle),
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
    );
  }
}
