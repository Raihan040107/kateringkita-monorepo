import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/models/cart_line.dart';
import 'package:kateringkita_pbl/models/order.dart';

void main() {
  final quote = Quote.fromJson({
    'items': [
      {
        'menu_id': 7,
        'menu_name': 'Martabak',
        'qty': 2,
        'unit_price': 20000,
        'line_total': 40000,
        'options': ['Keju'],
      },
    ],
    'subtotal': 40000,
    'discount': 0,
    'service_fee': 0,
    'total': 40000,
  });

  test('cartLinesFromReorder menggabungkan request dan quote', () {
    final lines = cartLinesFromReorder({
      'items': [
        {'menu_id': 7, 'qty': 2, 'option_ids': [3]},
      ],
      'pickup_point_id': 2,
    }, quote);

    expect(lines, hasLength(1));
    final l = lines.single;
    expect(l.menuId, 7);
    expect(l.qty, 2);
    expect(l.optionIds, [3]);
    expect(l.name, 'Martabak');
    expect(l.optionNames, ['Keju']);
    expect(l.unitPrice, 20000);
    expect(l.toJson(), {'menu_id': 7, 'qty': 2, 'option_ids': [3]});
  });

  test('request tanpa items menghasilkan daftar kosong', () {
    expect(cartLinesFromReorder({}, quote), isEmpty);
  });
}
