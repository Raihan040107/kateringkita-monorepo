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
