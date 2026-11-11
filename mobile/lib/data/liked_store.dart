import 'package:flutter/foundation.dart';

import '../models/menu.dart';
import '../services/api_client.dart';
import '../services/catalog_api.dart';

/// Menu favorit pembeli, disinkronkan dengan `GET/PUT/DELETE /me/favorites`.
/// Perubahan optimistik: daftar diperbarui dulu, dikembalikan bila server menolak.
class LikedStore {
  LikedStore._();

  static final ValueNotifier<List<MenuCard>> favorites =
      ValueNotifier<List<MenuCard>>(const []);

  static Future<void> load(ApiClient api) async {
    try {
      favorites.value = await api.favorites();
    } catch (_) {
      // dibiarkan kosong; dimuat ulang saat layar Liked dibuka
    }
  }

  static bool isLiked(int menuId) =>
      favorites.value.any((m) => m.id == menuId);

  /// Mengembalikan status baru (true = jadi favorit). Melempar [ApiException]
  /// bila server menolak; daftar sudah dikembalikan ke semula.
  static Future<bool> toggle(ApiClient api, MenuCard menu) async {
    final before = favorites.value;
    final wasLiked = isLiked(menu.id);
    favorites.value = wasLiked
        ? before.where((m) => m.id != menu.id).toList()
        : [menu.copyWith(isFavorite: true), ...before];
    try {
      if (wasLiked) {
        await api.removeFavorite(menu.id);
      } else {
        await api.addFavorite(menu.id);
      }
    } on ApiException {
      favorites.value = before;
      rethrow;
    }
    return !wasLiked;
  }

  static void clear() => favorites.value = const [];
}
