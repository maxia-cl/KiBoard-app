import 'package:flutter/material.dart';

/// Placeholder glyph vocabulary (FP only) — mirrors KiBoard-windows-host/src/lib/icons.js so the
/// two mock-ups read the same way during the FP demo. F3/F5 replace both with a real icon set.
const Map<String, IconData> _icons = {
  'app': Icons.apps,
  'brush': Icons.brush,
  'crop': Icons.crop,
  'undo': Icons.undo,
  'redo': Icons.redo,
  'save': Icons.save,
  'layers': Icons.layers,
  'opacity': Icons.opacity,
  'zoom': Icons.zoom_in,
  'screenshot': Icons.camera_alt,
  'windows': Icons.window,
  'mouse': Icons.mouse,
  'mic': Icons.mic,
  'volume': Icons.volume_up,
  'mode': Icons.sync,
  'folder': Icons.folder,
  'back': Icons.arrow_back,
  'page': Icons.skip_next,
  'obs': Icons.videocam,
  'macro': Icons.settings,
  'close': Icons.close,
};

IconData iconFor(String? name) => _icons[name] ?? Icons.crop_square;
