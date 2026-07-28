// Not a `flutter test` — a plain Dart script exercising the ACTUAL PairingClient shipped in the
// app against a real, running KiBoard-windows-host. Run manually with:
//   dart run test/manual_pairing_smoke.dart
// Prints the pairing code it received via pair_challenge; type it back in when prompted, or set
// KIBOARD_TEST_CODE_LOG to auto-read it from the host's own stderr log for a fully scripted run.
// ignore_for_file: avoid_print -- a console script; printing IS its output.
import 'dart:async';
import 'dart:io';

import 'package:kiboard_app/model/deck.dart';
import 'package:kiboard_app/net/pairing_client.dart';
import 'package:kiboard_app/net/ws_layout_source.dart';

Future<void> main() async {
  final client = PairingClient();
  await client.connect('127.0.0.1', 8770);
  print('Connected. Requesting a pairing code...');
  final expiresIn = await client.requestCode(device: 'manual-smoke-test', platform: 'linux');
  print('pair_challenge received, code valid for ${expiresIn}s.');

  final logPath = Platform.environment['KIBOARD_TEST_CODE_LOG'];
  String? code;
  if (logPath != null) {
    final lines = File(logPath).readAsLinesSync();
    for (final line in lines.reversed) {
      if (line.contains('"manual-smoke-test" wants to connect')) {
        code = line.split('code ').last.trim();
        break;
      }
    }
  }
  code ??= stdin.readLineSync()?.trim();
  if (code == null) {
    stderr.writeln('No code available (set KIBOARD_TEST_CODE_LOG or type one on stdin).');
    exit(1);
  }

  // REGRESSION GUARD. On a phone, a human takes seconds to read the code off the PC and type it.
  // That gap used to kill the socket: every `firstWhere` cancels its subscription on match, and
  // `asBroadcastStream` cancelled the underlying socket subscription once the last listener left,
  // so `pair_confirm` went into a dead connection and the reply never came. The script never
  // caught it because it reads the code from a log file in microseconds. This pause makes the
  // script behave like a human — remove it and the bug goes back to being invisible here.
  print('Waiting 12s before confirming (reproduces the human typing gap)...');
  await Future<void>.delayed(const Duration(seconds: 12));

  final result = await client.confirmCode(code);
  print('PAIRED ok. deviceId=${result.deviceId} host=${result.hostName}');
  await client.dispose();

  // --- The session (protocol §4), on the SAME client code the app ships. ---
  final session = WsLayoutSource(
    ip: '127.0.0.1',
    port: 8770,
    token: result.token,
    deviceId: result.deviceId,
    grid: const Grid(rows: 2, cols: 3), // deliberately NOT 5x3: proves the host repaginates
  );
  final name = await session.connect();
  print('hello_ack ok, host="$name"');

  final received = <Layout>[];
  final sub = session.layouts().listen(received.add);

  // The host pushes auto mode's layout as soon as `hello` succeeds.
  final auto = await _waitFor(received, (l) => l.mode == 'auto', 'the auto-mode layout');
  _describe(auto);
  if (auto.grid.rows != 2 || auto.grid.cols != 3) {
    stderr.writeln('FAIL: the host ignored the grid declared in hello.');
    exit(1);
  }

  await session.setMode('manual');
  final manual = await _waitFor(received, (l) => l.mode == 'manual', 'the manual deck');
  _describe(manual);
  if (manual.grid.rows != 2 || manual.grid.cols != 3) {
    stderr.writeln('FAIL: the deck was not repaginated to the declared grid.');
    exit(1);
  }

  // Press a key by POSITION. The host resolves it against its own config (§4.2) — this script
  // never sends an action, which is the whole point of the v2 change. Danger keys are skipped:
  // this drives the real desktop, and "Cerrar app" is alt+F4.
  final target = manual.keys.firstWhere((k) => k.kind == KeyKind.action && !k.danger);
  print('Pressing pos ${target.pos} ("${target.label}" -> ${target.action})...');
  await session.pressKey(pos: target.pos, press: 'short').timeout(const Duration(seconds: 5));
  print('key_result ok.');

  // §4.2's security property, end to end: a position that was never on the layout must come back
  // refused, not executed.
  final refused = await session
      .pressResult(pos: 99, press: 'short')
      .timeout(const Duration(seconds: 3));
  if (refused['ok'] == true) {
    stderr.writeln('FAIL: the host executed a key at a position that is not on the grid.');
    exit(1);
  }
  print('out-of-range press refused with "${refused['error']}" — correct.');

  final windows = await session.listWindows(0).timeout(const Duration(seconds: 5));
  print('windows: page ${windows.page}/${windows.pages}, grid '
      '${windows.grid.rows}x${windows.grid.cols}');
  for (final k in windows.keys.where((k) => k.windowId != null).take(4)) {
    print('  ${k.current ? "*" : " "} ${k.label} — ${k.sub}');
  }

  await sub.cancel();
  await session.dispose();
  print('\nEND-TO-END OK.');
}

void _describe(Layout l) {
  print(
    'layout: mode=${l.mode} source=${l.source.id} grid=${l.grid.rows}x${l.grid.cols} '
    'page=${l.page}/${l.pages} '
    'keys=${l.keys.where((k) => k.kind != KeyKind.empty).length} of ${l.keys.length}',
  );
  for (final k in l.keys.where((k) => k.kind != KeyKind.empty)) {
    print('  pos ${k.pos}: ${k.label} -> ${k.action ?? k.kind.name}');
  }
}

/// Waits for a layout matching [test] to show up in [seen]. Polling beats a stream matcher here
/// because the host pushes layouts unprompted, so the one being waited for may already have
/// arrived by the time this is called.
Future<Layout> _waitFor(List<Layout> seen, bool Function(Layout) test, String what) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    final hit = seen.where(test);
    if (hit.isNotEmpty) return hit.last;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  stderr.writeln('FAIL: timed out waiting for $what.');
  exit(1);
}
