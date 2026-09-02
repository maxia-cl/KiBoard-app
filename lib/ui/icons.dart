import 'package:flutter/material.dart';

class ExpressiveIconAsset {
  final String asset;
  final bool monochrome;

  const ExpressiveIconAsset(this.asset, {this.monochrome = false});
}

const _expressiveRoot = 'KiBoard-protocol/protocol/icons/expressive';
const Map<String, ExpressiveIconAsset> _expressiveIcons = {
  'model': ExpressiveIconAsset('$_expressiveRoot/model.svg'),
  'effort': ExpressiveIconAsset('$_expressiveRoot/effort.svg'),
  'find': ExpressiveIconAsset('$_expressiveRoot/find.svg'),
  'bolt': ExpressiveIconAsset('$_expressiveRoot/bolt.svg', monochrome: true),
  'prev': ExpressiveIconAsset('$_expressiveRoot/prev.svg', monochrome: true),
  'next': ExpressiveIconAsset('$_expressiveRoot/next.svg', monochrome: true),
  'scrollup': ExpressiveIconAsset(
    '$_expressiveRoot/scrollup.svg',
    monochrome: true,
  ),
  'scrolldown': ExpressiveIconAsset(
    '$_expressiveRoot/scrolldown.svg',
    monochrome: true,
  ),
  'undo': ExpressiveIconAsset('$_expressiveRoot/undo.svg', monochrome: true),
  'accept': ExpressiveIconAsset('$_expressiveRoot/accept.svg'),
  'close': ExpressiveIconAsset('$_expressiveRoot/close.svg'),
};

ExpressiveIconAsset? expressiveIconFor(String? name) => _expressiveIcons[name];

/// The glyph vocabulary, mirrored in KiBoard-windows-host/src/lib/icons.js so a key looks the same
/// on the phone as it does in the editor.
///
/// It used to hold 24 names while the host's profiles referenced 93, so **81 of them fell through
/// to a blank square** — "Aceptar", "Copiar", "Pegar", "Modelo" and most of the rest of the Claude
/// Code profile among them. The keys were not badly drawn; they were not drawn at all. Every name
/// any profile or deck uses now has a glyph.
///
/// Several names deliberately share one: `zoom`/`zoomin` and `vol`/`volume` are the same idea
/// reached by two routes, and a key is better with a right-but-repeated glyph than a unique wrong
/// one.
const Map<String, IconData> _icons = {
  // --- surfaces and navigation ---
  'app': Icons.apps,
  'apps': Icons.grid_view,
  'deck': Icons.dashboard,
  'work': Icons.work,
  'windows': Icons.window,
  'folder': Icons.folder,
  'newfolder': Icons.create_new_folder,
  'home': Icons.home,
  'back': Icons.arrow_left,
  'fwdnav': Icons.arrow_right,
  'prev': Icons.arrow_left,
  'next': Icons.arrow_right,
  'page': Icons.skip_next,
  'scrollup': Icons.arrow_drop_up,
  'scrolldown': Icons.arrow_drop_down,
  'tab': Icons.keyboard_tab,
  'find': Icons.search,
  'pin': Icons.push_pin,
  'history': Icons.history,
  'mode': Icons.sync,
  'macro': Icons.playlist_play,
  'settings': Icons.settings,
  'terminal': Icons.terminal,

  // --- editing ---
  'new': Icons.add_circle,
  'copy': Icons.file_copy,
  'paste': Icons.assignment,
  'cut': Icons.content_cut,
  'duplicate': Icons.file_copy,
  'delete': Icons.delete,
  'undo': Icons.undo,
  'redo': Icons.redo,
  'save': Icons.save,
  'rename': Icons.edit,
  'selectall': Icons.select_all,
  'cursor': Icons.highlight_alt,
  'move': Icons.open_with,
  'group': Icons.group_work,
  'replace': Icons.find_replace,
  'refresh': Icons.refresh,
  'repeat': Icons.repeat,
  'shuffle': Icons.shuffle,
  'filter': Icons.filter_alt,
  'sum': Icons.functions,
  'print': Icons.print,

  // --- text ---
  'text': Icons.text_fields,
  'bold': Icons.format_bold,
  'italic': Icons.format_italic,
  'underline': Icons.format_underlined,
  'format': Icons.format_align_left,
  'highlight': Icons.highlight,
  'note': Icons.sticky_note_2,
  'comment': Icons.chat_bubble,
  'link': Icons.link,

  // --- drawing ---
  'brush': Icons.brush,
  'pencil': Icons.edit,
  'eraser': Icons.cleaning_services,
  'fill': Icons.format_color_fill,
  'palette': Icons.palette,
  'colorpick': Icons.colorize,
  'crop': Icons.crop,
  'frame': Icons.crop_free,
  'rect': Icons.rectangle_outlined,
  'ellipse': Icons.panorama_fish_eye,
  'line': Icons.horizontal_rule,
  'rotate': Icons.rotate_right,
  'layers': Icons.layers,
  'opacity': Icons.opacity,
  // Colour swatches, not themes: filled reads as black, hollow as white.
  'dark': Icons.circle,
  'light': Icons.circle_outlined,

  // --- view ---
  'zoom': Icons.zoom_in,
  'zoomin': Icons.zoom_in,
  'zoomout': Icons.zoom_out,
  'fullscreen': Icons.fullscreen,
  'screenshot': Icons.camera_alt,
  'hand': Icons.pan_tool,
  'mouse': Icons.mouse,

  // --- media and capture ---
  'obs': Icons.videocam,
  'video': Icons.smart_display,
  'record': Icons.fiber_manual_record,
  'stream': Icons.sensors,
  'clip': Icons.movie,
  'play': Icons.play_arrow,
  'bolt': Icons.bolt,
  'subtitles': Icons.subtitles,
  'mic': Icons.mic,
  'mute': Icons.volume_off,
  'vol': Icons.volume_up,
  'volume': Icons.volume_up,

  // --- messages and people ---
  'send': Icons.send,
  'reply': Icons.reply,
  'replyall': Icons.reply_all,
  'forward': Icons.forward,
  'share': Icons.share,
  'archive': Icons.archive,
  'people': Icons.people,
  'assign': Icons.person_add_alt,
  'login': Icons.login,
  'logout': Icons.logout,
  'calendar': Icons.calendar_today,
  'star': Icons.star,

  // --- transfer ---
  'upload': Icons.upload,
  'download': Icons.download,

  // --- outcomes ---
  'accept': Icons.check_circle,
  'close': Icons.cancel,
  // Claude Code's own two: which model is answering, and how hard it is being asked to think.
  'model': Icons.psychology,
  'effort': Icons.speed,
};

/// Solid triangles have a smaller visible footprint than most Material glyphs, even when their
/// icon boxes have the same size. Keys use this semantic set to give only directional controls a
/// larger box without making every icon oversized.
const Set<String> directionalIconNames = {
  'back',
  'fwdnav',
  'prev',
  'next',
  'scrollup',
  'scrolldown',
};

bool isDirectionalIcon(String? name) => directionalIconNames.contains(name);

IconData iconFor(String? name) => _icons[name] ?? Icons.crop_square;

/// A DECK's icon. Falls back to the deck glyph rather than the blank square: in a list of decks,
/// an unknown name should still read as a deck instead of as a broken key.
IconData iconForDeck(String? name) => _icons[name] ?? Icons.dashboard;

/// Every name that has a glyph. The editor's icon picker offers these, and a test asserts the
/// host's profiles never name one that is missing.
Iterable<String> get iconNames => _icons.keys;
