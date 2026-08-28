import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../net/ws_layout_source.dart';
import '../tokens.g.dart';

/// Full-screen trackpad, ported from v1 (docs/implementation-plan.md §2 keeps it: it is one of the
/// few things v1 did that a Stream Deck does not do at all).
///
/// The GESTURES are v1's, unchanged, because they were tuned against real use: a sub-pixel
/// accumulator so slow drags do not lose micro-movement, a one-shot decision between pinch-zoom and
/// two-finger scroll so a gesture never flickers between the two, and drag as a LATCH rather than
/// the laptop "double-tap and hold", which is unreliable on a phone.
///
/// What changed is the wire. v1 sent action strings (`mouse:12,-4`, `hold:left`); protocol v2 §4.2
/// forbids that — an authenticated client must not be able to name an action — so everything here
/// goes through the `input` channel's closed vocabulary instead.
class TrackpadScreen extends StatefulWidget {
  final WsLayoutSource session;
  const TrackpadScreen({super.key, required this.session});

  @override
  State<TrackpadScreen> createState() => _TrackpadScreenState();
}

class _TrackpadScreenState extends State<TrackpadScreen> {
  static const _dpiKey = 'mouse_dpi';

  /// Pointer speed multiplier per level. v1's values, kept: they were chosen on hardware.
  static const _dpiMul = [1.0, 1.8, 2.8];
  static const _dpiName = ['Slow', 'Medium', 'Fast'];

  int _dpi = 0;

  /// Sub-pixel remainder. Sending only whole pixels and dropping the fraction makes slow, precise
  /// movement drift — the part of a trackpad people notice first.
  double _accX = 0, _accY = 0;

  bool _hint = true;
  bool _dragging = false;
  Offset? _touch;
  bool _touching = false;

  // Two-finger gesture state, held for the duration of one gesture.
  int _mode = 0; // 0 undecided, 2 scroll, 3 zoom
  double _lastScale = 1, _zoomAcc = 1, _accV = 0, _accH = 0, _decide = 0;
  IconData? _gestureIcon;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _dpi = (p.getInt(_dpiKey) ?? 0).clamp(0, 2));
    });
  }

  @override
  void dispose() {
    // SAFETY: leaving with the drag latched would leave the left button held down on the PC and
    // the desktop unusable. The host also releases it if this client disappears, but doing it here
    // covers the ordinary case of simply walking out of the screen.
    if (_dragging) widget.session.sendInput({'kind': 'drag', 'down': false});
    super.dispose();
  }

  Future<void> _cycleDpi() async {
    setState(() => _dpi = (_dpi + 1) % 3);
    HapticFeedback.selectionClick();
    (await SharedPreferences.getInstance()).setInt(_dpiKey, _dpi);
  }

  /// Latches the left button. A toggle beats the laptop trackpad's "double-tap and hold" here:
  /// holding a finger still on glass while dragging with another is awkward on a phone.
  void _toggleDrag() {
    setState(() => _dragging = !_dragging);
    HapticFeedback.mediumImpact();
    widget.session.sendInput({'kind': 'drag', 'down': _dragging});
  }

  void _showGesture(IconData icon) {
    if (_gestureIcon != icon) setState(() => _gestureIcon = icon);
  }

  void _onScaleStart(ScaleStartDetails _) {
    _mode = 0;
    _lastScale = 1;
    _zoomAcc = 1;
    _accV = 0;
    _accH = 0;
    _decide = 0;
    _accX = 0;
    _accY = 0;
    if (_hint) setState(() => _hint = false);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final send = widget.session.sendInput;

    // One finger: move the cursor.
    if (d.pointerCount < 2) {
      _accX += d.focalPointDelta.dx * _dpiMul[_dpi];
      _accY += d.focalPointDelta.dy * _dpiMul[_dpi];
      final ix = _accX.truncate();
      final iy = _accY.truncate();
      if (ix != 0 || iy != 0) {
        send({'kind': 'mouse', 'dx': ix, 'dy': iy});
        _accX -= ix;
        _accY -= iy;
      }
      return;
    }

    // Two fingers: decide ONCE between zoom and scroll, then stay there. Re-deciding mid-gesture
    // makes a diagonal two-finger drag stutter between scrolling and zooming.
    final ratio = d.scale / _lastScale;
    _lastScale = d.scale;
    if (_mode == 0) {
      _decide += d.focalPointDelta.distance;
      if ((d.scale - 1).abs() > 0.12) {
        _mode = 3;
      } else if (_decide > 16) {
        _mode = 2;
      } else {
        return;
      }
    }

    if (_mode == 3) {
      _zoomAcc *= ratio;
      while (_zoomAcc > 1.15) {
        send({'kind': 'zoom', 'n': 1});
        _zoomAcc /= 1.15;
        _showGesture(Icons.zoom_in);
        HapticFeedback.selectionClick();
      }
      while (_zoomAcc < 1 / 1.15) {
        send({'kind': 'zoom', 'n': -1});
        _zoomAcc *= 1.15;
        _showGesture(Icons.zoom_out);
        HapticFeedback.selectionClick();
      }
      return;
    }

    const step = 12.0; // pixels of finger travel per wheel tick
    _accV += d.focalPointDelta.dy;
    _accH += d.focalPointDelta.dx;
    while (_accV.abs() >= step) {
      final dir = _accV > 0 ? 1 : -1;
      send({'kind': 'scroll', 'n': dir});
      _accV -= dir * step;
      _showGesture(Icons.swap_vert);
      HapticFeedback.selectionClick();
    }
    while (_accH.abs() >= step) {
      final dir = _accH > 0 ? 1 : -1;
      send({'kind': 'hscroll', 'n': dir});
      _accH -= dir * step;
      _showGesture(Icons.swap_horiz);
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(DeckTokens.appBackground),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.mouse,
                    color: Color(DeckTokens.textSecondary),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Trackpad',
                      style: TextStyle(
                        color: Color(DeckTokens.textPrimary),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  TextButton(onPressed: _cycleDpi, child: Text(_dpiName[_dpi])),
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.close,
                    icon: const Icon(
                      Icons.cancel,
                      color: Color(DeckTokens.textSecondary),
                      size: 18,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(child: _pad()),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: _PadButton(
                      label: 'Drag',
                      active: _dragging,
                      onTap: _toggleDrag,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PadButton(
                      label: AppLocalizations.of(context)!.rightClick,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.session.sendInput({
                          'kind': 'click',
                          'button': 'right',
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      // Listener is passive — it does not join the gesture arena, so tracking the finger for the
      // glow cannot steal the gestures below it.
      child: Listener(
        onPointerDown: (e) => setState(() {
          _touch = e.localPosition;
          _touching = true;
        }),
        onPointerMove: (e) => setState(() => _touch = e.localPosition),
        onPointerUp: (_) => setState(() => _touching = false),
        onPointerCancel: (_) => setState(() => _touching = false),
        child: GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: (_) {
            if (_gestureIcon != null) setState(() => _gestureIcon = null);
          },
          // A real gesture cancels onTap by itself, so this is always a click. With the drag
          // latched it must NOT fire: a click is press+release, which would drop what is being
          // dragged half way.
          onTap: () {
            if (_hint) setState(() => _hint = false);
            if (_dragging) return;
            HapticFeedback.selectionClick();
            widget.session.sendInput({'kind': 'click', 'button': 'left'});
          },
          onLongPress: () {
            if (_hint) setState(() => _hint = false);
            if (_dragging) return;
            HapticFeedback.mediumImpact();
            widget.session.sendInput({'kind': 'click', 'button': 'right'});
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(DeckTokens.keyDefaultBackground),
              borderRadius: BorderRadius.circular(
                DeckTokens.bezelCornerRadiusPx,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (_touch != null)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 90),
                    left: _touch!.dx - 70,
                    top: _touch!.dy - 70,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _touching ? 1 : 0,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.12),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: IgnorePointer(
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 150),
                      scale: _gestureIcon == null ? 0.6 : 1,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _gestureIcon == null ? 0 : 1,
                        child: Icon(
                          _gestureIcon ?? Icons.mouse,
                          size: 84,
                          color: const Color(
                            DeckTokens.textSecondary,
                          ).withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_hint)
                  const Center(
                    child: IgnorePointer(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          '1 finger: move · tap: left click · hold: right click\n'
                          '2 fingers: scroll · pinch: zoom',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(DeckTokens.textSecondary),
                            height: 1.6,
                          ),
                        ),
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

class _PadButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PadButton({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? const Color(DeckTokens.accent)
              : const Color(DeckTokens.keyDefaultBackground),
          borderRadius: BorderRadius.circular(DeckTokens.keyCornerRadiusPx),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(DeckTokens.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
