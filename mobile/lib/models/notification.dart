import 'dart:convert';

import 'json.dart';

/// `GET /me/notifications`; `type` = order_status | promo | info.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    this.readAt,
    this.createdAt,
  });
  final int id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isUnread => readAt == null;
  String? get orderCode => asStringOrNull(data['order_code']);
  String? get orderStatus => asStringOrNull(data['status']);

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    var data = j['data'];
    if (data is String) {
      // kolom JSON bisa datang sebagai string
      try {
        data = asMap(jsonDecode(data));
      } catch (_) {
        data = <String, dynamic>{};
      }
    }
    return AppNotification(
      id: asInt(j['id']),
      type: '${j['type'] ?? 'info'}',
      title: '${j['title'] ?? ''}',
      body: '${j['body'] ?? ''}',
      data: asMap(data),
      readAt: asDate(j['read_at']),
      createdAt: asDate(j['created_at']),
    );
  }
}
