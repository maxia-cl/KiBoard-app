import 'package:flutter_test/flutter_test.dart';
import 'package:kiboard_app/model/deck.dart';

void main() {
  test('iconColor tints the glyph independently from the key cap', () {
    final key = DeckKey.fromLayoutJson({
      'pos': 0,
      'kind': 'action',
      'icon': 'bolt',
      'color': '#112233',
      'iconColor': '#FFD54A',
    });

    expect(key.color, 0xFF112233);
    expect(key.iconColor, 0xFFFFD54A);
  });
}
