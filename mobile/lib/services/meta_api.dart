import '../models/json.dart';
import '../models/meta.dart';
import 'api_client.dart';

extension MetaApi on ApiClient {
  Future<List<Category>> categories() async =>
      asList((await get('/meta/categories'))['data']).map(Category.fromJson).toList();

  Future<List<PickupPoint>> pickupPoints() async =>
      asList((await get('/meta/pickup-points'))['data']).map(PickupPoint.fromJson).toList();

  Future<AppSettings> settings() async =>
      AppSettings.fromJson(asMap((await get('/meta/settings'))['data']));
}
