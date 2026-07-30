import 'package:flutter/material.dart';

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
  'back': Icons.arrow_back,
  'fwdnav': Icons.arrow_forward,
  'prev': Icons.navigate_before,
  'next': Icons.navigate_next,
  'page': Icons.skip_next,
  'scrollup': Icons.keyboard_arrow_up,
  'scrolldown': Icons.keyboard_arrow_down,
  'tab': Icons.keyboard_tab,
  'find': Icons.search,
  'pin': Icons.push_pin,
  'history': Icons.history,
  'mode': Icons.sync,
  'macro': Icons.playlist_play,
  'settings': Icons.settings,
  'terminal': Icons.terminal,

  // --- editing ---
  'new': Icons.add,
  'copy': Icons.content_copy,
  'paste': Icons.content_paste,
  'cut': Icons.content_cut,
  'duplicate': Icons.copy_all,
  'delete': Icons.delete_outline,
  'undo': Icons.undo,
  'redo': Icons.redo,
  'save': Icons.save,
  'rename': Icons.drive_file_rename_outline,
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
  'comment': Icons.chat_bubble_outline,
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
  'clip': Icons.movie_outlined,
  'play': Icons.play_arrow,
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
  'archive': Icons.archive_outlined,
  'people': Icons.people,
  'assign': Icons.person_add_alt,
  'login': Icons.login,
  'logout': Icons.logout,
  'calendar': Icons.calendar_today,
  'star': Icons.star_border,

  // --- transfer ---
  'upload': Icons.upload,
  'download': Icons.download,

  // --- outcomes ---
  'accept': Icons.check,
  'close': Icons.close,
  // Claude Code's own two: which model is answering, and how hard it is being asked to think.
  'model': Icons.psychology,
  'effort': Icons.speed,
};

IconData iconFor(String? name) => _icons[name] ?? Icons.crop_square;

/// A DECK's icon. Falls back to the deck glyph rather than the blank square: in a list of decks,
/// an unknown name should still read as a deck instead of as a broken key.
IconData iconForDeck(String? name) => _icons[name] ?? Icons.dashboard;

/// Every name that has a glyph. The editor's icon picker offers these, and a test asserts the
/// host's profiles never name one that is missing.
Iterable<String> get iconNames => _icons.keys;
