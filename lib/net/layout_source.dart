// Seam from docs/implementation-plan.md phase FP: `MockLayoutSource` now, `WsLayoutSource` (the
// real WebSocket client) in F3. Only this file's contract changes between the two.
import '../model/deck.dart';

abstract class LayoutSource {
  /// Pushed whenever the host would push a fresh `layout` (protocol §4.1): foreground app change,
  /// mode switch, folder navigation, or a config edit.
  Stream<Layout> layouts();

  /// Protocol §4.1 `page_preload`: pages the client is NOT on, sent unasked so a swipe has
  /// something to draw behind the finger. Never changes what is on screen.
  ///
  /// Empty by default — a single-page source, or a mock, simply never emits, and no caller has to
  /// know which kind it is holding.
  Stream<Layout> preloads() => const Stream.empty();

  /// Protocol §4.4 `toast`: something the HOST wants said. It is the host's only channel for
  /// narrating what it did, which matters precisely because §4.2 means the phone cannot know —
  /// it sent a position, and only the PC knows what that turned into.
  ///
  /// Already translated by the host, in this session's language.
  Stream<String> toasts() => const Stream.empty();

  /// Protocol §4.2: the phone sends the key it pressed, never the action.
  ///
  /// [option] and [text] are the answer to a key that asks something first — the branch chosen out
  /// of a `picker:`/`colorpicker:`, or what was typed for a `prompt:`. Still not an action: an
  /// index into the host's own key, and the text that goes in the hole of its own template.
  Future<void> pressKey({required int pos, required String press, int? option, String? text});

  /// Protocol §4.4 `set_mode`.
  Future<void> setMode(String mode, {String? deckId});

  /// Protocol §4.3 `list_windows` — already paginated and MRU-ordered by the host.
  Future<WindowsPage> listWindows(int page);

  /// Protocol §4.3 `focus_window`.
  Future<void> focusWindow(int windowId);
}
