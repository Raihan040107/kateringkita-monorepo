import '../models/json.dart';
import '../models/menu.dart';
import 'api_client.dart';

extension CatalogApi on ApiClient {
  /// `GET /menus` — hanya menu aktif dari toko terverifikasi yang sedang buka.
  Future<List<MenuCard>> menus({
    String? q,
    String? category,
    String? merchant,
    int? pickupPointId,
    String? sort,
    int page = 1,
    int limit = 50,
  }) async {
    final r = await get('/menus', query: {
      'q': q,
      'category': category,
      'merchant': merchant,
      'pickup_point_id': pickupPointId?.toString(),
      'sort': sort,
      'page': '$page',
      'limit': '$limit',
    });
    return asList(r['data']).map(MenuCard.fromJson).toList();
  }

  Future<MenuDetail> menu(int id) async =>
      MenuDetail.fromJson(asMap((await get('/menus/$id'))['data']));

  Future<List<MenuReview>> menuReviews(int id) async =>
      asList((await get('/menus/$id/reviews'))['data']).map(MenuReview.fromJson).toList();

  Future<List<MenuCard>> favorites() async =>
      asList((await get('/me/favorites', query: {'limit': '100'}))['data'])
          .map(MenuCard.fromJson)
          .toList();

  Future<void> addFavorite(int menuId) => put('/me/favorites/$menuId');

  Future<void> removeFavorite(int menuId) => delete('/me/favorites/$menuId');
}
