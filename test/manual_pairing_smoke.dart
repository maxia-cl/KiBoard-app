// Not a `flutter test` — a plain Dart script exercising the ACTUAL PairingClient shipped in the
// app against a real, running KiBoard-windows-host. Run manually with:
//   dart run test/manual_pairing_smoke.dart
// Prints the pairing code it received via pair_challenge; type it back in when prompted, or set
// KIBOARD_TEST_CODE_LOG to auto-read it from the host's own stderr log for a fully scripted run.
// ignore_for_file: avoid_print -- a console script; printing IS its output.
import 'dart:io';

import 'package:kiboard_app/net/pairing_client.dart';

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

  final result = await client.confirmCode(code);
  print('PAIRED ok. deviceId=${result.deviceId} token=${result.token} host=${result.hostName}');
  await client.dispose();
}
