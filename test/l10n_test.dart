import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `.arb` files against the code that is supposed to use them.
///
/// This exists because seventeen strings were defined, translated into both languages, and never
/// referenced — while the English they were written to replace sat inlined at the call site. The
/// worst of them was the discovery empty state, which is the single screen a stuck user reaches,
/// in the one language they might not read. Nothing catches that: the app compiles, the tests
/// pass, and the analyzer has no opinion about a key nobody asked for.
void main() {
  final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
  final es = jsonDecode(File('lib/l10n/app_es.arb').readAsStringSync()) as Map<String, dynamic>;
  final keys = en.keys.where((k) => !k.startsWith('@')).toList();

  test('every string is actually used', () {
    final source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('l10n'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    final orphans = keys.where((k) => !RegExp(r'\.' + k + r'\b').hasMatch(source)).toList();
    expect(
      orphans,
      isEmpty,
      reason:
          'defined and translated but never shown — either wire it up at the call site, or '
          'delete it. A string nobody reaches is a translation nobody benefits from.',
    );
  });

  test('the two languages carry the same keys', () {
    final spanish = es.keys.where((k) => !k.startsWith('@')).toSet();
    expect(spanish.difference(keys.toSet()), isEmpty, reason: 'in Spanish but not English');
    expect(keys.toSet().difference(spanish), isEmpty, reason: 'in English but not Spanish');
  });

  // ponytail: no "is it actually translated" check. Decks, Auto, Manual and the manual's own name
  // are the same word in both languages, so it would need an allowlist that grows with every
  // product term — maintenance for a signal the two tests above already mostly carry.
}
