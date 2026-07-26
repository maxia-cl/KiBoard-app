import 'package:flutter/material.dart';

import '../../model/deck.dart';
import '../../net/layout_source.dart';
import '../tokens.g.dart';
import '../windows/window_switcher_screen.dart';
import 'device_bezel.dart';
import 'key_grid.dart';

class DeckScreen extends StatefulWidget {
  final LayoutSource layoutSource;
  final String hostName;

  const DeckScreen({super.key, required this.layoutSource, required this.hostName});

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  late final Stream<Layout> _layouts = widget.layoutSource.layouts();

  void _handlePress(Layout layout, int pos, String press) {
    final key = layout.keys[pos];
    widget.layoutSource.pressKey(pos: pos, press: press);
    if (key.action == 'windows') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WindowSwitcherScreen(layoutSource: widget.layoutSource)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: SafeArea(
        child: StreamBuilder<Layout>(
          stream: _layouts,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Color(DeckTokens.accent)));
            }
            final layout = snapshot.data!;
            return Column(
              children: [
                _TopBar(layout: layout, layoutSource: widget.layoutSource),
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth - 32;
                        final cols = layout.grid.cols;
                        final gapRatio = DeckTokens.keyGapRatioOfSide;
                        var keySize = maxWidth / (cols + (cols - 1) * gapRatio);
                        keySize = keySize.clamp(40.0, 96.0);
                        return DeviceBezel(
                          gridWidth: KeyGrid.widthFor(layout.grid, keySize),
                          gridHeight: KeyGrid.heightFor(layout.grid, keySize),
                          pageCount: layout.pages,
                          currentPage: layout.page,
                          child: KeyGrid(
                            grid: layout.grid,
                            keys: layout.keys,
                            keySize: keySize,
                            onKeyPress: (pos, press) => _handlePress(layout, pos, press),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final Layout layout;
  final LayoutSource layoutSource;
  const _TopBar({required this.layout, required this.layoutSource});

  @override
  Widget build(BuildContext context) {
    final title = layout.mode == 'auto' ? (layout.source.appName ?? 'Auto') : (layout.source.name ?? 'Manual');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            layout.mode == 'auto' ? Icons.bolt : Icons.dashboard_customize,
            color: const Color(DeckTokens.textSecondary),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Color(DeckTokens.textPrimary), fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownButton<String>(
            value: layout.mode,
            dropdownColor: const Color(0xFF1E1E20),
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Color(DeckTokens.textPrimary), fontSize: 13),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('Auto')),
              DropdownMenuItem(value: 'manual', child: Text('Manual')),
            ],
            onChanged: (mode) {
              if (mode != null) layoutSource.setMode(mode);
            },
          ),
          const SizedBox(width: 8),
          Icon(Icons.settings, color: const Color(DeckTokens.textSecondary), size: 20),
        ],
      ),
    );
  }
}
