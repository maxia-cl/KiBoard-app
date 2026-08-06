import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../model/deck.dart';
import '../net/layout_source.dart';

/// Reads bundled fixtures instead of a WebSocket (docs/implementation-plan.md phase FP).
/// Folder/page navigation is simulated locally: the real host resolves it server-side, the
/// wire shape is identical either way (protocol §4.1), so `WsLayoutSource` (F3) is a drop-in swap.
class MockLayoutSource extends LayoutSource {
  final _controller = StreamController<Layout>.broadcast();

  late Layout _autoLayout;
  late Layout _launcherLayout;
  late Layout _obsFolderLayout;
  final _windowsPages = <int, WindowsPage>{};

  String _mode = 'auto';
  bool _inFolder = false;
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    const fixtures = 'KiBoard-protocol/protocol/fixtures';
    final autoJson = jsonDecode(
      await rootBundle.loadString('$fixtures/layout-auto-photoshop.json'),
    );
    final launcherJson = jsonDecode(
      await rootBundle.loadString('$fixtures/layout-manual-launcher.json'),
    );
    final folderJson = jsonDecode(await rootBundle.loadString('$fixtures/layout-folder.json'));
    _autoLayout = Layout.fromJson(autoJson as Map<String, dynamic>);
    _launcherLayout = Layout.fromJson(launcherJson as Map<String, dynamic>);
    _obsFolderLayout = Layout.fromJson(folderJson as Map<String, dynamic>);

    for (final n in [0, 1]) {
      final json = jsonDecode(
        await rootBundle.loadString('$fixtures/windows-switcher-page-$n.json'),
      );
      _windowsPages[n] = WindowsPage.fromJson(json as Map<String, dynamic>);
    }
    _loaded = true;
  }

  Layout get _current {
    if (_mode == 'auto') return _autoLayout;
    return _inFolder ? _obsFolderLayout : _launcherLayout;
  }

  @override
  Stream<Layout> layouts() {
    _ensureLoaded().then((_) => _controller.add(_current));
    return _controller.stream;
  }

  @override
  Future<void> pressKey({required int pos, required String press}) async {
    await _ensureLoaded();
    if (pos >= _current.keys.length) return;
    final key = _current.keys[pos];
    if (key.kind == KeyKind.folder) {
      _inFolder = true;
      _controller.add(_current);
    } else if (key.kind == KeyKind.page) {
      // Both the folder's "Back" key and the launcher's "More" key are kind "page"; in FP the
      // only extra page is the folder's parent, so a page-kind press always exits the folder.
      _inFolder = false;
      _controller.add(_current);
    }
    // Regular action keys execute nothing in FP — see the MOCK-UP watermark (R11).
  }

  @override
  Future<void> setMode(String mode, {String? deckId}) async {
    await _ensureLoaded();
    _mode = mode;
    _inFolder = false;
    _controller.add(_current);
  }

  @override
  Future<WindowsPage> listWindows(int page) async {
    await _ensureLoaded();
    return _windowsPages[page] ?? _windowsPages[0]!;
  }

  @override
  Future<void> focusWindow(int windowId) async {
    // No-op in FP: there is no real window to focus.
  }

  void dispose() {
    _controller.close();
  }
}
