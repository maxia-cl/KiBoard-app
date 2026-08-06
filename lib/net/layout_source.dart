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

  /// Protocol §4.2: the phone sends the key it pressed, never the action.
  Future<void> pressKey({required int pos, required String press});

  /// Protocol §4.4 `set_mode`.
  Future<void> setMode(String mode, {String? deckId});

  /// Protocol §4.3 `list_windows` — already paginated and MRU-ordered by the host.
  Future<WindowsPage> listWindows(int page);

  /// Protocol §4.3 `focus_window`.
  Future<void> focusWindow(int windowId);
}
