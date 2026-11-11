import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/data/liked_store.dart';
import 'package:kateringkita_pbl/models/menu.dart';
import 'package:kateringkita_pbl/models/meta.dart';
import 'package:kateringkita_pbl/services/api_client.dart';

MenuCard _menu(int id) => MenuCard(
      id: id,
      name: 'Menu $id',
      price: 10000,
      unitLabel: 'porsi',
      category: const Category(id: 4, name: 'Snack & Kue', slug: 'snack'),
      merchant: const MerchantRef(
          id: 1, slug: 'toko', businessName: 'Toko', isOpen: true),
      available: 5,
      badge: 'available',
      ratingAvg: 0,
      ratingCount: 0,
      isFavorite: false,
    );

ApiClient _api(int status) => ApiClient(
      MockClient((_) async => http.Response(
            status == 204
                ? ''
                : '{"error":{"code":"SERVER","message":"gagal"}}',
            status,
          )),
      readToken: () async => 'token',
    );

void main() {
  setUp(LikedStore.clear);

  test('toggle menambah lalu menghapus favorit', () async {
    final api = _api(204);
    expect(await LikedStore.toggle(api, _menu(1)), isTrue);
    expect(LikedStore.isLiked(1), isTrue);
    expect(LikedStore.favorites.value.single.isFavorite, isTrue);
    expect(await LikedStore.toggle(api, _menu(1)), isFalse);
    expect(LikedStore.isLiked(1), isFalse);
  });

  test('server menolak: daftar dikembalikan seperti semula', () async {
    await expectLater(
      LikedStore.toggle(_api(500), _menu(2)),
      throwsA(isA<ApiException>()),
    );
    expect(LikedStore.isLiked(2), isFalse);
    expect(LikedStore.favorites.value, isEmpty);
  });
}
