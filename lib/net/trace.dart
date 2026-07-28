import 'package:flutter/foundation.dart';

/// Debug-only tracing for the connection flow, which is the part that cannot be reproduced on a
/// desktop Dart VM: the phone is where mDNS, the real radio and Android's network policy live.
///
/// The `KB2:` prefix matters — KiBoard **v1** is still installed on some test phones and its own
/// reconnect loop logs `KB onError` / `KB onDone` into the same logcat. Grepping for the wrong
/// prefix sends you chasing a dead app's errors, which already cost one debugging session.
void trace(String message) {
  if (kDebugMode) {
    debugPrint('KB2: $message');
  }
}
