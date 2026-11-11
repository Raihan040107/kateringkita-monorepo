import '../models/json.dart';
import '../models/order.dart';
import 'api_client.dart';

/// Hasil `POST /orders/:code/reorder`: permintaan asli + hitungan ulang.
class ReorderResult {
  const ReorderResult({required this.request, required this.quote});
  final Map<String, dynamic> request;
  final Quote quote;
}

extension OrdersApi on ApiClient {
  Future<Quote> quote(Map<String, dynamic> body) async =>
      Quote.fromJson(asMap((await post('/orders/quote', body: body))['data']));

  /// `POST /orders` dengan `Idempotency-Key`; body = quote + payment_method.
  Future<Order> createOrder(Map<String, dynamic> body, String idempotencyKey) async =>
      Order.fromJson(asMap((await post('/orders',
              body: body, headers: {'Idempotency-Key': idempotencyKey}))['data']));

  Future<Order> order(String code) async =>
      Order.fromJson(asMap((await get('/orders/$code'))['data']));

  /// `tab` = active | completed | cancelled
  Future<List<Order>> myOrders({required String tab, String? q, int page = 1, int limit = 50}) async {
    final r = await get('/me/orders', query: {'tab': tab, 'q': q, 'page': '$page', 'limit': '$limit'});
    return asList(r['data']).map(Order.fromJson).toList();
  }

  /// `{wa_number, message, url}`
  Future<Map<String, dynamic>> whatsapp(String code) async =>
      asMap((await get('/orders/$code/whatsapp'))['data']);

  Future<Order> cancel(String code, String? reason) async => Order.fromJson(asMap(
      (await post('/orders/$code/cancel', body: {if (reason != null && reason.isNotEmpty) 'reason': reason}))['data']));

  Future<Order> complete(String code) async =>
      Order.fromJson(asMap((await post('/orders/$code/complete'))['data']));

  Future<ReorderResult> reorder(String code) async {
    final d = asMap((await post('/orders/$code/reorder'))['data']);
    return ReorderResult(request: asMap(d['request']), quote: Quote.fromJson(asMap(d['quote'])));
  }

  /// items: `[{menu_id, rating, comment}]`
  Future<void> review(String code, List<Map<String, dynamic>> items) =>
      post('/orders/$code/reviews', body: {'items': items});

  /// bank = bca | bni | bri
  Future<Order> createVa(String code, String bank) async =>
      Order.fromJson(asMap((await post('/orders/$code/va', body: {'bank': bank}))['data']));

  Future<Order> payOnline(String code) async =>
      Order.fromJson(asMap((await post('/orders/$code/online'))['data']));
}
