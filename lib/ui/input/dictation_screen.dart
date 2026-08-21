import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../l10n/app_localizations.dart';
import '../../net/ws_layout_source.dart';
import '../tokens.g.dart';

/// Push-to-talk dictation, ported from v1: hold the button, speak, release, and the text is typed
/// on the PC. Built for the AI-agent profiles, where the useful unit of input is a paragraph of
/// prose that is miserable to type on a phone keyboard and worse on a desktop one you are not
/// sitting at.
///
/// The transcription happens ON THE PHONE — Android's own engine, already speaking the user's
/// language — and only the finished text crosses the network, as `input` kind `text` (§4.2). No
/// audio ever leaves the device.
class DictationScreen extends StatefulWidget {
  final WsLayoutSource session;
  const DictationScreen({super.key, required this.session});

  @override
  State<DictationScreen> createState() => _DictationScreenState();
}

class _DictationScreenState extends State<DictationScreen> {
  final _speech = stt.SpeechToText();
  bool _ready = false;
  bool _listening = false;
  String _partial = '';
  String? _error;

  /// Set when the user lets go: the final result arrives asynchronously, and only then is there
  /// something worth sending.
  bool _sendOnFinal = false;
  Timer? _finalFallback;

  @override
  void dispose() {
    _finalFallback?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _start() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(
        () => _error = status.isPermanentlyDenied
            ? AppLocalizations.of(context)!.micDenied
            : AppLocalizations.of(context)!.micNeeded,
      );
      return;
    }
    if (!_ready) {
      _ready = await _speech.initialize(
        // `error_no_match` just means nothing was understood — not worth an error message, the
        // empty result already says it.
        onError: (_) {
          if (mounted && _listening) setState(() => _listening = false);
        },
      );
      if (!_ready) {
        setState(() => _error = AppLocalizations.of(context)!.noSpeech);
        return;
      }
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _partial = '';
      _error = null;
      _listening = true;
      _sendOnFinal = false;
    });

    await _speech.listen(
      // Generous windows on purpose: with the defaults Android stops after ~5s of silence, which
      // cuts off any dictation with a pause for thought in it. The user's finger decides when it
      // ends, not the engine.
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 60),
      ),
      onResult: (r) {
        if (!mounted) return;
        setState(() => _partial = r.recognizedWords);
        if (r.finalResult && _sendOnFinal) _send();
      },
    );
  }

  void _stop() {
    if (!_listening) return;
    setState(() => _listening = false);
    _sendOnFinal = true;
    _speech.stop(); // the final result comes back through onResult
    // Fallback for engines that never deliver a final result: send the last partial rather than
    // silently losing what was said.
    _finalFallback?.cancel();
    _finalFallback = Timer(const Duration(milliseconds: 900), _send);
  }

  void _send() {
    _finalFallback?.cancel();
    final text = _partial.trim();
    if (text.isEmpty) return;
    widget.session.sendInput({'kind': 'text', 'text': text});
    HapticFeedback.selectionClick();
    if (mounted) setState(() => _partial = '');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.mic,
                    color: Color(DeckTokens.textSecondary),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.dictate,
                      style: const TextStyle(
                        color: Color(DeckTokens.textPrimary),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: t.close,
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
            Expanded(
              // Scrollable: what lands here is whatever the person said, at 20 pt, and a long
              // sentence dictated with the phone held sideways has nowhere to go otherwise.
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error ??
                        (_partial.isNotEmpty
                            ? _partial
                            : _listening
                            ? t.listening
                            : t.holdAndSpeak),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(
                        _error != null
                            ? DeckTokens.accent
                            : DeckTokens.textPrimary,
                      ),
                      fontSize: _partial.isNotEmpty ? 20 : 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              // Push-to-talk, not a toggle: holding is unambiguous about when the microphone is
              // live, which matters for something that listens to a room.
              child: GestureDetector(
                onTapDown: (_) => _start(),
                onTapUp: (_) => _stop(),
                onTapCancel: _stop,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 96,
                  decoration: BoxDecoration(
                    color: _listening
                        ? const Color(DeckTokens.accent)
                        : const Color(DeckTokens.keyDefaultBackground),
                    borderRadius: BorderRadius.circular(
                      DeckTokens.bezelCornerRadiusPx,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.mic,
                      size: 40,
                      color: const Color(DeckTokens.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
