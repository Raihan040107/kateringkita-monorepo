import 'json.dart';
import 'order.dart';

/// Satu baris pesanan yang dibawa ke layar checkout (tanpa keranjang).
class CartLine {
  CartLine({
    required this.menuId,
    required this.name,
    required this.qty,
    this.imageUrl,
    this.optionIds = const [],
    this.optionNames = const [],
    this.isPreorder = false,
    this.unitPrice = 0,
  });

  final int menuId;
  final String name;
  final String? imageUrl;
  int qty;
  final List<int> optionIds;
  final List<String> optionNames;
  final bool isPreorder;

  /// Harga satuan termasuk opsi, hanya untuk tampilan sebelum quote tiba.
  final int unitPrice;

  Map<String, dynamic> toJson() => {
        'menu_id': menuId,
        'qty': qty,
        if (optionIds.isNotEmpty) 'option_ids': optionIds,
      };
}

/// Baris checkout dari `POST /orders/:code/reorder`: `request.items` memberi
/// menu/qty/opsi, `quote.items` memberi nama, harga, dan nama opsi.
List<CartLine> cartLinesFromReorder(Map<String, dynamic> request, Quote quote) {
  final items = request['items'];
  if (items is! List) return const [];
  return [
    for (final raw in items)
      if (raw is Map) _lineFromReorder(Map<String, dynamic>.from(raw), quote),
  ];
}

CartLine _lineFromReorder(Map<String, dynamic> m, Quote quote) {
  final menuId = asInt(m['menu_id']);
  final q = quote.items.where((x) => x.menuId == menuId).firstOrNull;
  final optionIds = m['option_ids'];
  return CartLine(
    menuId: menuId,
    name: q?.name ?? 'Menu',
    qty: asInt(m['qty'], 1),
    optionIds: optionIds is List ? [for (final o in optionIds) asInt(o)] : const [],
    optionNames: q?.options ?? const [],
    unitPrice: q?.unitPrice ?? 0,
  );
}
