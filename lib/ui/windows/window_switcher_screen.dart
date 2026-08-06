import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPage(0);
  }

  Future<void> _loadPage(int page) async {
    if (!_pages.containsKey(page)) {
      final data = await widget.layoutSource.listWindows(page);
      if (!mounted) return;
      setState(() => _pages[page] = data);
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.window, color: Color(DeckTokens.textSecondary), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Open windows',
                      style: TextStyle(
                        color: Color(DeckTokens.textPrimary),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(DeckTokens.textSecondary)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(DeckTokens.accent)))
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final first = _pages[0]!;
                          // Same shell and sizing as the deck — §4.3 says same grid, same key.
                          final keySize = KeyGrid.sizeToFit(
                            first.grid,
                            constraints.maxWidth - DeviceBezel.chromeWidth(),
                            constraints.maxHeight -
                                DeviceBezel.chromeHeightFor(first.pages, constraints.maxHeight),
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
                                if (page == null) return const SizedBox.shrink();
                                return KeyGrid(
                                  grid: page.grid,
                                  keys: page.keys,
                                  keySize: keySize,
                                  onKeyPress: (pos, _) async {
                                    final windowId = page.keys[pos].windowId;
                                    if (windowId == null) return;
                                    await widget.layoutSource.focusWindow(windowId);
                                    if (context.mounted) Navigator.of(context).pop();
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
