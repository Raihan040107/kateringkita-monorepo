import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/models/menu.dart';
import 'package:kateringkita_pbl/models/meta.dart';
import 'package:kateringkita_pbl/models/notification.dart';
import 'package:kateringkita_pbl/models/order.dart';
import 'package:kateringkita_pbl/models/user.dart';

// Fixture mengikuti kontrak backend (backend/docs/API.md).
const kartu = {
  'id': 7,
  'name': 'Es Teh Lemon',
  'image_url': null,
  'price': 8000,
  'unit_label': 'gelas',
  'category': {'id': 5, 'name': 'Minuman', 'slug': 'minuman'},
  'merchant': {'id': 3, 'slug': 'demo-03', 'business_name': 'Es Citra', 'is_open': true},
  'available': 3,
  'badge': 'low_stock',
  'rating_avg': '4.50',
  'rating_count': 2,
  'is_favorite': false,
};

void main() {
  test('PublicUser', () {
    final u = PublicUser.fromJson({
      'id': 9,
      'role': 'customer',
      'full_name': 'Budi Santoso',
      'email': null,
      'phone': '081234567890',
      'avatar_url': null,
      'favorite_pickup_point_id': 2,
    });
    expect(u.email, isNull);
    expect(u.favoritePickupPointId, 2);
    expect(u.initials, 'BS');
  });

  test('MenuCard: DECIMAL string, badge, canOrder', () {
    final m = MenuCard.fromJson(kartu);
    expect(m.price, 8000);
    expect(m.ratingAvg, 4.5);
    expect(m.imageUrl, isNull);
    expect(m.merchant.isOpen, isTrue);
    expect(m.canOrder, isTrue);
    expect(MenuCard.fromJson({...kartu, 'available': 0}).canOrder, isFalse);
    expect(m.copyWith(isFavorite: true).isFavorite, isTrue);
  });

  test('MenuDetail: opsi, pre-order, titik temu toko', () {
    final d = MenuDetail.fromJson({
      ...kartu,
      'description': 'Segar',
      'options': [
        {'id': 1, 'name': 'Less sugar', 'extra_price': 0},
        {'id': 2, 'name': 'Jumbo', 'extra_price': 3000},
      ],
      'min_order_qty': 2,
      'prep_minutes': 15,
      'is_preorder': true,
      'preorder_days': 1,
      'merchant': {
        ...kartu['merchant'] as Map,
        'logo_url': 'https://x/logo.png',
        'open_time': '07:00',
        'close_time': '16:00',
        'pickup_points': [
          {'id': 2, 'name': 'Kantin Vokasi UB'},
          {'id': 3, 'name': 'Gazebo FILKOM'},
        ],
      },
    });
    expect(d.card.id, 7);
    expect(d.options.map((o) => o.extraPrice), [0, 3000]);
    expect(d.minOrderQty, 2);
    expect(d.isPreorder, isTrue);
    expect(d.pickupPoints.length, 2);
    expect(d.logoUrl, 'https://x/logo.png');
  });

  test('Order daftar (tanpa payment) dan detail VA', () {
    final dasar = {
      'code': 'KK-240101-ABCD',
      'status': 'holding',
      'payment_method': 'va',
      'payment_status': 'unpaid',
      'hold_until': '2026-11-12T08:30:00.000Z',
      'seconds_left': 299,
      'pickup_point': {'id': 2, 'name': 'Kantin Vokasi UB'},
      'items': [
        {
          'menu_id': 7,
          'menu_name': 'Es Teh Lemon',
          'qty': 2,
          'unit_price': 8000,
          'options': [{'id': 2, 'name': 'Jumbo', 'extra_price': 3000}],
          'line_total': 22000,
        }
      ],
      'subtotal': '22000.00',
      'discount': 0,
      'service_fee': 1000,
      'total': 23000,
      'note': null,
      'pickup_at': null,
      'cancel_reason': null,
      'cancelled_by': null,
      'created_at': '2026-11-12T08:25:00.000Z',
      'updated_at': '2026-11-12T08:25:00.000Z',
      'merchant': {'id': 3, 'business_name': 'Es Citra', 'wa_number': '081100000003'},
      'can_cancel': true,
      'can_complete': false,
      'can_review': false,
    };
    final daftar = Order.fromJson(dasar);
    expect(daftar.payment, isNull);
    expect(daftar.subtotal, 22000);
    expect(daftar.items.single.options, ['Jumbo']);
    expect(daftar.isHolding, isTrue);
    expect(daftar.remainingSeconds(daftar.fetchedAt.add(const Duration(seconds: 10))), 289);
    expect(daftar.remainingSeconds(daftar.fetchedAt.add(const Duration(seconds: 1000))), 0);

    final detail = Order.fromJson({
      ...dasar,
      'payment': {
        'method': 'va',
        'status': 'pending',
        'amount': 23000,
        'va': {'bank': 'bca', 'va_number': '8127000012345', 'expires_at': '2026-11-12T08:30:00.000Z'},
      },
    });
    expect(detail.payment!.vaNumber, '8127000012345');
    expect(detail.payment!.vaBank, 'bca');
    expect(detail.payment!.paymentUrl, isNull);

    final online = Order.fromJson({
      ...dasar,
      'payment_method': 'online',
      'payment': {'method': 'online', 'status': 'pending', 'amount': 23000, 'payment_url': 'https://app.sandbox.midtrans.com/snap/v4/redirection/x'},
    });
    expect(online.payment!.paymentUrl, startsWith('https://'));
    expect(online.payment!.vaNumber, isNull);
  });

  test('Quote dengan warnings', () {
    final q = Quote.fromJson({
      'items': [
        {'menu_id': 7, 'menu_name': 'Es Teh', 'qty': 1, 'unit_price': 8000, 'line_total': 8000}
      ],
      'subtotal': 8000,
      'discount': 800,
      'service_fee': 0,
      'total': 7200,
      'warnings': [
        {'code': 'LOW_STOCK', 'message': 'Sisa 2 porsi.'}
      ],
    });
    expect(q.total, 7200);
    expect(q.warnings, ['Sisa 2 porsi.']);
  });

  test('AppNotification: data JSON sebagai map atau string', () {
    final a = AppNotification.fromJson({
      'id': 1,
      'type': 'order_status',
      'title': 'Pesanan dikonfirmasi',
      'body': 'x',
      'data': {'order_code': 'KK-1', 'status': 'confirmed'},
      'read_at': null,
      'created_at': '2026-11-12T08:25:00.000Z',
    });
    expect(a.orderCode, 'KK-1');
    expect(a.isUnread, isTrue);
    final b = AppNotification.fromJson({'id': 2, 'type': 'promo', 'title': 't', 'body': 'b', 'data': '{"order_code":"KK-2"}', 'read_at': '2026-11-12T08:25:00.000Z'});
    expect(b.orderCode, 'KK-2');
    expect(b.isUnread, isFalse);
  });

  test('PickupPoint & AppSettings', () {
    expect(PickupPoint.fromJson({'id': 1, 'name': 'Gedung Vokasi', 'description': null}).description, isNull);
    final s = AppSettings.fromJson({'service_fee': '1000', 'timezone': 'Asia/Jakarta', 'cs_whatsapp': null});
    expect(s.serviceFee, 1000);
    expect(s.csWhatsapp, isNull);
  });
}
