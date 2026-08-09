// Mirrors the wire `layout` / `windows` messages in KiBoard-protocol/protocol/README.md §3-4.
// `folderId` and `targetPage` are mock-only conveniences (see lib/mock/README.md); they never
// cross the wire, the real host resolves folder/page navigation server-side.

class Grid {
  final int rows;
  final int cols;
  const Grid({required this.rows, required this.cols});

  int get capacity => rows * cols;

  factory Grid.fromJson(Map<String, dynamic> json) =>
      Grid(rows: json['rows'] as int, cols: json['cols'] as int);
}

enum KeyKind { action, folder, page, empty }

KeyKind _kindFromString(String? value) {
  switch (value) {
    case 'action':
      return KeyKind.action;
    case 'folder':
      return KeyKind.folder;
    case 'page':
      return KeyKind.page;
    default:
      return KeyKind.empty;
  }
}

class DeckKey {
  final int pos;
  final String? label;
  final String? icon;
  final String? image;
  final int? color; // 0xAARRGGBB, parsed from a "#RRGGBB" string
  final String? action;
  final String? hold;
  final String? doublePress;
  final bool danger;
  final bool stateOn;

  /// `state.running` (§3), which the host attaches per send for keys that open an app. **Null means
  /// this key is not one of those** — the difference matters: `false` is "that app is not open yet"
  /// and drives the launching colour, while null is "there is nothing to wait for".
  final bool? running;
  final KeyKind kind;
  final String? folderId;
  final int? targetPage;
  // Present only on `windows`-shaped keys (protocol §4.3).
  final int? windowId;
  final String? sub;
  final bool current;
  final bool minimized;

  const DeckKey({
    required this.pos,
    this.label,
    this.icon,
    this.image,
    this.color,
    this.action,
    this.hold,
    this.doublePress,
    this.danger = false,
    this.stateOn = false,
    this.running,
    this.kind = KeyKind.empty,
    this.folderId,
    this.targetPage,
    this.windowId,
    this.sub,
    this.current = false,
    this.minimized = false,
  });

  static DeckKey empty(int pos) => DeckKey(pos: pos, kind: KeyKind.empty);

  factory DeckKey.fromLayoutJson(Map<String, dynamic> json) {
    final state = json['state'] as Map<String, dynamic>?;
    final colorHex = json['color'] as String?;
    return DeckKey(
      pos: json['pos'] as int,
      label: json['label'] as String?,
      icon: json['icon'] as String?,
      image: json['image'] as String?,
      color: colorHex != null ? int.parse('FF${colorHex.substring(1)}', radix: 16) : null,
      action: json['action'] as String?,
      hold: json['hold'] as String?,
      doublePress: json['double'] as String?,
      danger: json['danger'] as bool? ?? false,
      stateOn: state?['on'] as bool? ?? false,
      running: state?['running'] as bool?,
      kind: _kindFromString(json['kind'] as String?),
    );
  }

  factory DeckKey.fromWindowJson(Map<String, dynamic> json) {
    final state = json['state'] as Map<String, dynamic>?;
    return DeckKey(
      pos: json['pos'] as int,
      label: json['label'] as String?,
      image: json['image'] as String?,
      sub: json['sub'] as String?,
      windowId: json['id'] as int?,
      current: state?['current'] as bool? ?? false,
      minimized: state?['minimized'] as bool? ?? false,
      kind: KeyKind.action,
    );
  }

  DeckKey copyWith({String? folderId, int? targetPage}) => DeckKey(
    pos: pos,
    label: label,
    icon: icon,
    image: image,
    color: color,
    action: action,
    hold: hold,
    doublePress: doublePress,
    danger: danger,
    stateOn: stateOn,
    running: running,
    kind: kind,
    folderId: folderId ?? this.folderId,
    targetPage: targetPage ?? this.targetPage,
    windowId: windowId,
    sub: sub,
    current: current,
    minimized: minimized,
  );
}

class LayoutSourceInfo {
  final String kind; // "profile" | "deck"
  final String id;
  final String? name;
  final String? appName;
  final String? appIcon;
  const LayoutSourceInfo({
    required this.kind,
    required this.id,
    this.name,
    this.appName,
    this.appIcon,
  });

  factory LayoutSourceInfo.fromJson(Map<String, dynamic> json) => LayoutSourceInfo(
    kind: json['kind'] as String,
    id: json['id'] as String,
    name: json['name'] as String?,
    appName: json['appName'] as String?,
    appIcon: json['appIcon'] as String?,
  );
}

/// Fills the holes in a page WITHOUT inventing cells the host chose not to fill.
///
/// The host sends exactly the cells it may use: the whole grid, minus whatever the client reserved
/// for itself (§4.1 `grid.reserve`). Padding to `grid.capacity` regardless put empty keys back into
/// the reserved cells — so the panel drawn over them had key caps underneath, which is precisely
/// what "funciona muy mal" looked like.
///
/// Holes in the middle are still filled: a deck with a gap at position 3 must draw an empty cell
/// there, not shift everything left.
List<DeckKey> _densify(List<DeckKey> sparse, Grid grid) {
  if (sparse.isEmpty) return List<DeckKey>.generate(grid.capacity, DeckKey.empty);
  final filled = sparse.map((k) => k.pos).reduce((a, b) => a > b ? a : b) + 1;
  final dense = List<DeckKey>.generate(filled.clamp(1, grid.capacity), DeckKey.empty);
  for (final key in sparse) {
    if (key.pos < dense.length) dense[key.pos] = key;
  }
  return dense;
}

class Layout {
  final String mode; // "auto" | "manual"
  final LayoutSourceInfo source;
  final Grid grid;
  final int page;
  final int pages;
  final List<DeckKey> keys; // dense, length == grid.capacity
  final int? sysVol;
  final bool sysMuted;

  const Layout({
    required this.mode,
    required this.source,
    required this.grid,
    required this.page,
    required this.pages,
    required this.keys,
    this.sysVol,
    this.sysMuted = false,
  });

  factory Layout.fromJson(Map<String, dynamic> json) {
    final grid = Grid.fromJson(json['grid'] as Map<String, dynamic>);
    final sparse = (json['keys'] as List)
        .map((k) => DeckKey.fromLayoutJson(k as Map<String, dynamic>))
        .toList();
    final dense = _densify(sparse, grid);
    final sys = json['sys'] as Map<String, dynamic>?;
    return Layout(
      mode: json['mode'] as String,
      source: LayoutSourceInfo.fromJson(json['source'] as Map<String, dynamic>),
      grid: grid,
      page: json['page'] as int,
      pages: json['pages'] as int,
      keys: dense,
      sysVol: sys?['vol'] as int?,
      sysMuted: sys?['muted'] as bool? ?? false,
    );
  }

  Layout withKeys(List<DeckKey> newKeys) => Layout(
    mode: mode,
    source: source,
    grid: grid,
    page: page,
    pages: pages,
    keys: newKeys,
    sysVol: sysVol,
    sysMuted: sysMuted,
  );
}

/// A deck the host offers, as named in `hello_ack` (protocol §2). Just enough to list them and ask
/// for one by id — the keys themselves only ever arrive in a `layout`.
class DeckSummary {
  final String id;
  final String name;
  final String? icon;

  const DeckSummary({required this.id, required this.name, this.icon});

  factory DeckSummary.fromJson(Map<String, dynamic> json) => DeckSummary(
    id: json['id'] as String,
    name: json['name'] as String? ?? json['id'] as String,
    icon: json['icon'] as String?,
  );
}

class WindowsPage {
  final Grid grid;
  final int page;
  final int pages;
  final List<DeckKey> keys;

  const WindowsPage({
    required this.grid,
    required this.page,
    required this.pages,
    required this.keys,
  });

  factory WindowsPage.fromJson(Map<String, dynamic> json) {
    final grid = Grid.fromJson(json['grid'] as Map<String, dynamic>);
    final sparse = (json['keys'] as List)
        .map((k) => DeckKey.fromWindowJson(k as Map<String, dynamic>))
        .toList();
    final dense = _densify(sparse, grid);
    return WindowsPage(
      grid: grid,
      page: json['page'] as int,
      pages: json['pages'] as int,
      keys: dense,
    );
  }
}
