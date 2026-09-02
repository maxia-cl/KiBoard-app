import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiboard_app/ui/icons.dart';

void main() {
  test('the selected icon language uses triangles and filled outcomes', () {
    expect(iconFor('prev'), Icons.arrow_left);
    expect(iconFor('next'), Icons.arrow_right);
    expect(iconFor('scrollup'), Icons.arrow_drop_up);
    expect(iconFor('scrolldown'), Icons.arrow_drop_down);
    expect(iconFor('accept'), Icons.check_circle);
    expect(iconFor('close'), Icons.cancel);
  });

  test('only directional triangles receive the enlarged key treatment', () {
    for (final name in [
      'back',
      'fwdnav',
      'prev',
      'next',
      'scrollup',
      'scrolldown',
    ]) {
      expect(isDirectionalIcon(name), isTrue, reason: name);
    }
    expect(isDirectionalIcon('play'), isFalse);
    expect(isDirectionalIcon('accept'), isFalse);
    expect(isDirectionalIcon(null), isFalse);
  });

  test('standard actions use their filled variants', () {
    expect(iconFor('new'), Icons.add_circle);
    expect(iconFor('copy'), Icons.file_copy);
    expect(iconFor('paste'), Icons.assignment);
    expect(iconFor('delete'), Icons.delete);
    expect(iconFor('comment'), Icons.chat_bubble);
    expect(iconFor('archive'), Icons.archive);
    expect(iconFor('star'), Icons.star);
  });

  test('Codex keeps the chosen brain, gauge and bolt metaphors', () {
    expect(iconFor('model'), Icons.psychology);
    expect(iconFor('effort'), Icons.speed);
    expect(iconFor('bolt'), Icons.bolt);
    expect(expressiveIconFor('model')?.asset, endsWith('/model.svg'));
    expect(expressiveIconFor('effort')?.asset, endsWith('/effort.svg'));
    expect(expressiveIconFor('bolt')?.monochrome, isTrue);
  });
}
