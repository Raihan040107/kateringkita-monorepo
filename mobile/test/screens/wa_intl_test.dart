import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/screens/orders/whatsapp_generator_screen.dart';

void main() {
  test('waIntl mengubah 08xx menjadi 628xx dan membuang pemisah', () {
    expect(waIntl('0812-3456-7890'), '6281234567890');
    expect(waIntl('6281234567890'), '6281234567890');
  });
}
