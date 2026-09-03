import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiboard_app/l10n/app_localizations.dart';
import 'package:kiboard_app/model/deck.dart';
import 'package:kiboard_app/net/layout_source.dart';
import 'package:kiboard_app/settings.dart';
import 'package:kiboard_app/ui/deck/deck_screen.dart';
import 'package:kiboard_app/ui/tokens.g.dart';

const _captureKey = ValueKey<String>('store-capture');

class _StoreSource extends LayoutSource {
  _StoreSource(this.layout, {required this.manualEnabled});

  final Layout layout;
  final StreamController<Layout> _layouts =
      StreamController<Layout>.broadcast();

  @override
  final bool manualEnabled;

  @override
  List<DeckSummary> get decks => const [
    DeckSummary(id: 'launcher', name: 'Launcher', icon: 'apps'),
    DeckSummary(id: 'work', name: 'Mi tablero', icon: 'work'),
  ];

  @override
  Stream<Layout> layouts() {
    scheduleMicrotask(() => _layouts.add(layout));
    return _layouts.stream;
  }

  @override
  Stream<bool> manualFeature() async* {
    yield manualEnabled;
  }

  @override
  Future<bool> setManualEnabled(bool enabled) async => false;

  @override
  Future<void> pressKey({
    required int pos,
    required String press,
    int? option,
    String? text,
  }) async {}

  @override
  Future<void> setMode(String mode, {String? deckId}) async {}

  @override
  Future<WindowsPage> listWindows(int page) async => const WindowsPage(
    grid: Grid(rows: 1, cols: 1),
    page: 0,
    pages: 1,
    keys: [
      DeckKey(pos: 0, label: 'KiBoard', windowId: 1, kind: KeyKind.action),
    ],
  );

  @override
  Future<void> focusWindow(int windowId) async {}

  Future<void> close() => _layouts.close();
}

DeckKey _key(
  int pos,
  String label,
  String icon, {
  int? color,
  int? iconColor,
  bool danger = false,
  bool stateOn = false,
}) => DeckKey(
  pos: pos,
  label: label,
  icon: icon,
  action: 'preview:$pos',
  color: color,
  iconColor: iconColor,
  danger: danger,
  stateOn: stateOn,
  kind: KeyKind.action,
);

Layout _autoLayout() => Layout(
  mode: 'auto',
  source: const LayoutSourceInfo(
    kind: 'profile',
    id: 'codex',
    appName: 'ChatGPT · Codex',
  ),
  grid: const Grid(rows: 5, cols: 3),
  page: 0,
  pages: 1,
  keys: [
    _key(0, 'Modelo', 'model'),
    _key(
      1,
      'Speed',
      'effort',
      color: 0xFFD8AE27,
      iconColor: 0xFF17191C,
      stateOn: true,
    ),
    _key(2, 'Aceptar', 'accept'),
    _key(3, 'Buscar', 'find'),
    _key(4, 'Anterior', 'prev'),
    _key(5, 'Siguiente', 'next'),
    _key(6, 'Subir', 'scrollup'),
    _key(7, 'Bajar', 'scrolldown'),
    _key(8, 'Deshacer', 'undo'),
    _key(9, 'Copiar', 'copy'),
    _key(10, 'Pegar', 'paste'),
    _key(11, 'Captura', 'screenshot'),
    _key(12, 'Ventanas', 'windows'),
    DeckKey.empty(13),
    DeckKey.empty(14),
  ],
  sysVol: 62,
);

Layout _launcherLayout() => Layout(
  mode: 'manual',
  source: const LayoutSourceInfo(
    kind: 'deck',
    id: 'launcher',
    name: 'Launcher',
  ),
  grid: const Grid(rows: 5, cols: 3),
  page: 0,
  pages: 2,
  keys: [
    _key(0, 'ChatGPT', 'app', color: 0xFF28433A),
    _key(1, 'Chrome', 'app', color: 0xFF243F61),
    _key(2, 'Spotify', 'app', color: 0xFF244632),
    _key(3, 'WhatsApp', 'app', color: 0xFF25443A),
    _key(4, 'Terminal', 'terminal'),
    _key(5, 'Fotos', 'app', color: 0xFF47385C),
    _key(6, 'VLC', 'play', color: 0xFF5B3A28),
    _key(7, 'Paint', 'palette'),
    _key(8, 'Bloc de notas', 'note'),
    _key(9, 'Configuración', 'settings'),
    _key(10, 'Windows', 'windows'),
    _key(11, 'Captura', 'screenshot'),
    DeckKey.empty(12),
    DeckKey.empty(13),
    _key(14, 'Más', 'next'),
  ],
  sysVol: 62,
);

Layout _manualLayout() => Layout(
  mode: 'manual',
  source: const LayoutSourceInfo(kind: 'deck', id: 'work', name: 'Mi tablero'),
  grid: const Grid(rows: 5, cols: 3),
  page: 0,
  pages: 1,
  keys: [
    _key(0, 'Copiar', 'copy'),
    _key(1, 'Pegar', 'paste'),
    _key(2, 'Deshacer', 'undo'),
    _key(3, 'Captura', 'screenshot'),
    _key(4, 'Micrófono', 'mic', stateOn: true),
    _key(5, 'Volumen', 'volume'),
    _key(6, 'Reproducir', 'play'),
    _key(7, 'Ventanas', 'windows'),
    _key(8, 'Buscar', 'find'),
    _key(9, 'Guardar', 'save'),
    _key(10, 'Terminal', 'terminal'),
    _key(11, 'Inicio', 'home'),
    DeckKey.empty(12),
    DeckKey.empty(13),
    _key(14, 'Cerrar app', 'close', danger: true),
  ],
  sysVol: 62,
);

Widget _app(LayoutSource source) => RepaintBoundary(
  key: _captureKey,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('es'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'StoreRoboto',
      scaffoldBackgroundColor: const Color(DeckTokens.appBackground),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(DeckTokens.accent),
        brightness: Brightness.dark,
      ),
    ),
    home: DeckScreen(layoutSource: source, hostName: 'PC de KiBoard'),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  _StoreSource source,
  Size logicalSize,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = logicalSize;
  await tester.pumpWidget(_app(source));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _capture(
  WidgetTester tester,
  String relativePath,
  double pixelRatio,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Could not encode $relativePath');
    final output = File('store-assets/screenshots/$relativePath');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(data.buffer.asUint8List(), flush: true);
  });
}

Future<void> _renderSet(
  WidgetTester tester, {
  required String folder,
  required Size logicalSize,
  required double pixelRatio,
}) async {
  for (final item in <(String, Layout)>[
    ('01-automatico.png', _autoLayout()),
    ('02-launcher.png', _launcherLayout()),
    ('03-manual.png', _manualLayout()),
  ]) {
    final source = _StoreSource(item.$2, manualEnabled: true);
    await _pump(tester, source, logicalSize);
    await _capture(tester, '$folder/${item.$1}', pixelRatio);
    await tester.pumpWidget(const SizedBox.shrink());
    await source.close();
  }

  final settingsSource = _StoreSource(_autoLayout(), manualEnabled: true);
  await _pump(tester, settingsSource, logicalSize);
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
  await _capture(tester, '$folder/04-configuracion.png', pixelRatio);
  await tester.pumpWidget(const SizedBox.shrink());
  await settingsSource.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('generate Play Store screenshots from the production UI', (
    tester,
  ) async {
    // Widget tests normally use the Ahem metric font, which deliberately renders letters as
    // rectangles. Load Flutter's bundled Roboto so the exported store images show real UI text.
    File findFlutterFont(String name) {
      var cursor = File(Platform.resolvedExecutable).parent;
      for (var depth = 0; depth < 8; depth++) {
        final candidate = File(
          '${cursor.path}${Platform.pathSeparator}artifacts${Platform.pathSeparator}'
          'material_fonts${Platform.pathSeparator}$name',
        );
        if (candidate.existsSync()) {
          return candidate;
        }
        cursor = cursor.parent;
      }
      throw StateError('Could not find Flutter font $name');
    }

    Future<void> loadFont(String family, String name) async {
      final fontFile = findFlutterFont(name);
      final fontBytes = await tester.runAsync(fontFile.readAsBytes);
      if (fontBytes == null) {
        throw StateError('Could not load ${fontFile.path}');
      }
      final loader = FontLoader(family)
        ..addFont(
          Future.value(ByteData.sublistView(Uint8List.fromList(fontBytes))),
        );
      await loader.load();
    }

    await loadFont('StoreRoboto', 'roboto-regular.ttf');
    await loadFont('Ahem', 'roboto-regular.ttf');
    await loadFont('MaterialIcons', 'MaterialIcons-Regular.otf');

    Settings.instance.value = const SettingsData(
      haptics: false,
      sound: false,
      languageCode: 'es',
    );

    // Google Play-ready dimensions: 1080x1920, 1920x1080, and 1600x2560.
    await _renderSet(
      tester,
      folder: 'phone-portrait',
      logicalSize: const Size(360, 640),
      pixelRatio: 3,
    );
    await _renderSet(
      tester,
      folder: 'phone-landscape',
      logicalSize: const Size(640, 360),
      pixelRatio: 3,
    );
    await _renderSet(
      tester,
      folder: 'tablet-portrait',
      logicalSize: const Size(800, 1280),
      pixelRatio: 2,
    );
  });
}
