import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/core/app_time.dart';

void main() {
  test('isoWib memakai jam dinding yang dipilih dengan offset +07:00', () {
    expect(
      AppTime.isoWib(DateTime(2026, 11, 13, 9, 5)),
      '2026-11-13T09:05:00+07:00',
    );
  });

  test('mmss membatasi di nol dan menambah nol di depan', () {
    expect(AppTime.mmss(65), '01:05');
    expect(AppTime.mmss(-3), '00:00');
  });
}
