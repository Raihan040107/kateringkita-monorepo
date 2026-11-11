import '../models/json.dart';
import '../models/notification.dart';
import 'api_client.dart';

class NotificationPage {
  const NotificationPage({required this.items, required this.unreadCount});
  final List<AppNotification> items;
  final int unreadCount;
}

extension NotificationsApi on ApiClient {
  Future<NotificationPage> notifications({bool unread = false, int page = 1, int limit = 50}) async {
    final r = await get('/me/notifications', query: {
      if (unread) 'unread': '1',
      'page': '$page',
      'limit': '$limit',
    });
    return NotificationPage(
      items: asList(r['data']).map(AppNotification.fromJson).toList(),
      unreadCount: asInt(asMap(r['meta'])['unread_count']),
    );
  }

  /// Mengembalikan sisa belum dibaca.
  Future<int> markRead(List<int> ids) async =>
      asInt(asMap((await post('/me/notifications/read', body: {'ids': ids}))['data'])['unread_count']);

  Future<int> markAllRead() async =>
      asInt(asMap((await post('/me/notifications/read', body: {'all': true}))['data'])['unread_count']);
}
