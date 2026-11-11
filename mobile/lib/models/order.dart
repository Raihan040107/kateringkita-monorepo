import 'json.dart';

class OrderItem {
  const OrderItem({
    required this.menuId,
    required this.menuName,
    required this.qty,
    required this.unitPrice,
    required this.options,
    required this.lineTotal,
  });
  final int menuId;
  final String menuName;
  final int qty;
  final int unitPrice;
  final List<String> options;
  final int lineTotal;

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        menuId: asInt(j['menu_id']),
        menuName: '${j['menu_name'] ?? j['name'] ?? ''}',
        qty: asInt(j['qty']),
        unitPrice: asInt(j['unit_price']),
        options: j['options'] is List
            ? (j['options'] as List)
                .map((o) => o is Map ? '${o['name']}' : '$o')
                .toList()
            : const [],
        lineTotal: asInt(j['line_total']),
      );
}

/// Info pembayaran di `GET /orders/:code` (null di daftar pesanan).
class Payment {
  const Payment({
    required this.method,
    required this.status,
    required this.amount,
    this.vaBank,
    this.vaNumber,
    this.vaExpiresAt,
    this.paymentUrl,
  });
  final String method;
  final String status;
  final int amount;
  final String? vaBank;
  final String? vaNumber;
  final DateTime? vaExpiresAt;
  final String? paymentUrl;

  factory Payment.fromJson(Map<String, dynamic> j) {
    final va = asMap(j['va']);
    return Payment(
      method: '${j['method'] ?? ''}',
      status: '${j['status'] ?? ''}',
      amount: asInt(j['amount']),
      vaBank: asStringOrNull(va['bank']),
      vaNumber: asStringOrNull(va['va_number']),
      vaExpiresAt: asDate(va['expires_at']),
      paymentUrl: asStringOrNull(j['payment_url']),
    );
  }
}

class Order {
  const Order({
    required this.code,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.pickupPointId,
    required this.pickupPointName,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.serviceFee,
    required this.total,
    required this.merchantName,
    required this.canCancel,
    required this.canComplete,
    required this.canReview,
    required this.fetchedAt,
    this.holdUntil,
    this.secondsLeft,
    this.note,
    this.pickupAt,
    this.cancelReason,
    this.cancelledBy,
    this.createdAt,
    this.updatedAt,
    this.merchantWa,
    this.payment,
  });

  final String code;

  /// holding | confirmed | cooking | ready | completed | cancelled | expired
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime? holdUntil;
  final int? secondsLeft;
  final int pickupPointId;
  final String pickupPointName;
  final List<OrderItem> items;
  final int subtotal;
  final int discount;
  final int serviceFee;
  final int total;
  final String? note;
  final DateTime? pickupAt;
  final String? cancelReason;
  final String? cancelledBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String merchantName;
  final String? merchantWa;
  final bool canCancel;
  final bool canComplete;
  final bool canReview;
  final Payment? payment;

  /// Saat respons diterima; dipakai menghitung mundur dari `secondsLeft`.
  final DateTime fetchedAt;

  bool get isHolding => status == 'holding';
  bool get isActive => const {'holding', 'confirmed', 'cooking', 'ready'}.contains(status);
  bool get isFinal => !isActive;

  /// Sisa detik tahan pesanan sekarang (0 bila habis / tidak holding).
  int remainingSeconds([DateTime? now]) {
    if (secondsLeft == null) return 0;
    final elapsed = (now ?? DateTime.now()).difference(fetchedAt).inSeconds;
    final left = secondsLeft! - elapsed;
    return left < 0 ? 0 : left;
  }

  factory Order.fromJson(Map<String, dynamic> j) {
    final pp = asMap(j['pickup_point']);
    final m = asMap(j['merchant']);
    return Order(
      code: '${j['code'] ?? ''}',
      status: '${j['status'] ?? ''}',
      paymentMethod: '${j['payment_method'] ?? ''}',
      paymentStatus: '${j['payment_status'] ?? ''}',
      holdUntil: asDate(j['hold_until']),
      secondsLeft: asIntOrNull(j['seconds_left']),
      pickupPointId: asInt(pp['id']),
      pickupPointName: '${pp['name'] ?? ''}',
      items: asList(j['items']).map(OrderItem.fromJson).toList(),
      subtotal: asInt(j['subtotal']),
      discount: asInt(j['discount']),
      serviceFee: asInt(j['service_fee']),
      total: asInt(j['total']),
      note: asStringOrNull(j['note']),
      pickupAt: asDate(j['pickup_at']),
      cancelReason: asStringOrNull(j['cancel_reason']),
      cancelledBy: asStringOrNull(j['cancelled_by']),
      createdAt: asDate(j['created_at']),
      updatedAt: asDate(j['updated_at']),
      merchantName: '${m['business_name'] ?? ''}',
      merchantWa: asStringOrNull(m['wa_number']),
      canCancel: asBool(j['can_cancel']),
      canComplete: asBool(j['can_complete']),
      canReview: asBool(j['can_review']),
      payment: j['payment'] is Map ? Payment.fromJson(asMap(j['payment'])) : null,
      fetchedAt: DateTime.now(),
    );
  }
}

class QuoteItem {
  const QuoteItem({
    required this.menuId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    required this.options,
  });
  final int menuId;
  final String name;
  final int qty;
  final int unitPrice;
  final int lineTotal;
  final List<String> options;

  factory QuoteItem.fromJson(Map<String, dynamic> j) => QuoteItem(
        menuId: asInt(j['menu_id']),
        name: '${j['menu_name'] ?? j['name'] ?? ''}',
        qty: asInt(j['qty']),
        unitPrice: asInt(j['unit_price']),
        lineTotal: asInt(j['line_total']),
        options: j['options'] is List
            ? (j['options'] as List)
                .map((o) => o is Map ? '${o['name']}' : '$o')
                .toList()
            : const [],
      );
}

/// `POST /orders/quote`
class Quote {
  const Quote({
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.serviceFee,
    required this.total,
    required this.warnings,
  });
  final List<QuoteItem> items;
  final int subtotal;
  final int discount;
  final int serviceFee;
  final int total;
  final List<String> warnings;

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        items: asList(j['items']).map(QuoteItem.fromJson).toList(),
        subtotal: asInt(j['subtotal']),
        discount: asInt(j['discount']),
        serviceFee: asInt(j['service_fee']),
        total: asInt(j['total']),
        warnings: j['warnings'] is List
            ? (j['warnings'] as List)
                .map((w) => w is Map ? '${w['message'] ?? w}' : '$w')
                .toList()
            : const [],
      );
}
