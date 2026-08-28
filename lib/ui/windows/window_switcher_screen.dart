import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../model/deck.dart';
import '../../net/layout_source.dart';
import '../deck/device_bezel.dart';
import '../deck/key_grid.dart';
import '../tokens.g.dart';

/// §3.5/§4.3: "another key pad" — same grid, same key, same swipe pagination as a deck. Windows
/// arrive already MRU-ordered and paginated by the host; this screen only renders and swipes.
class WindowSwitcherScreen extends StatefulWidget {
  final LayoutSource layoutSource;
  const WindowSwitcherScreen({super.key, required this.layoutSource});

  @override
  State<WindowSwitcherScreen> createState() => _WindowSwitcherScreenState();
}

class _WindowSwitcherScreenState extends State<WindowSwitcherScreen> {
  final _pageController = PageController();
  final Map<int, WindowsPage> _pages = {};
  int _currentPage = 0;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadPage(0);
  }

  /// `listWindows` gives up by THROWING, and nothing used to catch it: the first page never
  /// arrived, `_loading` was never cleared, and the screen showed a spinner for ever — after an
  /// eight-second wait during which it looked like it was working.
  Future<void> _loadPage(int page) async {
    if (!_pages.containsKey(page)) {
      try {
        final data = await widget.layoutSource.listWindows(page);
        if (!mounted) return;
        setState(() => _pages[page] = data);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _failed = true;
          _loading = false;
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _failed = false;
      _loading = false;
    });
  }

  void _retry() {
    setState(() {
      _failed = false;
      _loading = true;
    });
    _loadPage(_currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(DeckTokens.appBackground),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.window,
                    color: Color(DeckTokens.textSecondary),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.openWindows,
                      style: const TextStyle(
                        color: Color(DeckTokens.textPrimary),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: t.close,
                    icon: const Icon(
                      Icons.cancel,
                      color: Color(DeckTokens.textSecondary),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(DeckTokens.accent),
                      ),
                    )
                  // A sentence and a way forward, the same bargain the deck makes when the host is
                  // asleep. A spinner here would be a lie: nothing is still coming.
                  : _failed
                  ? _Message(
                      text: t.windowsFailed,
                      action: TextButton(
                        onPressed: _retry,
                        child: Text(t.retry),
                      ),
                    )
                  : (_pages[0]?.keys.isEmpty ?? true)
                  ? _Message(text: t.noOpenWindows)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final first =
                              _pages[0]!; // guarded by the empty/failed branches above
                          // Same shell and sizing as the deck — §4.3 says same grid, same key.
                          final keySize = KeyGrid.sizeToFit(
                            first.grid,
                            constraints.maxWidth - DeviceBezel.chromeWidth(),
                            constraints.maxHeight -
                                DeviceBezel.chromeHeightFor(
                                  first.pages,
                                  constraints.maxHeight,
                                ),
                          );
                          return DeviceBezel(
                            gridWidth: KeyGrid.widthFor(first.grid, keySize),
                            gridHeight: KeyGrid.heightFor(first.grid, keySize),
                            pageCount: first.pages,
                            currentPage: _currentPage,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: first.pages,
                              onPageChanged: (i) {
                                setState(() => _currentPage = i);
                                _loadPage(i);
                              },
                              itemBuilder: (context, i) {
                                final page = _pages[i];
                                if (page == null) {
                                  return const SizedBox.shrink();
                                }
                                return KeyGrid(
                                  grid: page.grid,
                                  keys: page.keys,
                                  keySize: keySize,
                                  onKeyPress: (pos, _) async {
                                    final windowId = page.keys[pos].windowId;
                                    if (windowId == null) return;
                                    await widget.layoutSource.focusWindow(
                                      windowId,
                                    );
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sentence in the middle of the pad, with an optional way forward. The deck says the same kind
/// of thing when the host is asleep; a spinner would claim something is still on its way.
class _Message extends StatelessWidget {
  final String text;
  final Widget? action;
  const _Message({required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(DeckTokens.textSecondary),
                fontSize: 14,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
