import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/liked_store.dart';
import '../data/token_store.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_api.dart';

/// Sesi pembeli: token di secure storage, profil dari `GET /me`.
class SessionProvider extends ChangeNotifier {
  SessionProvider(
    this._api, {
    this.readToken = TokenStore.readToken,
    this.saveToken = TokenStore.saveToken,
    this.clearToken = TokenStore.clear,
  });

  final ApiClient _api;
  final Future<String?> Function() readToken;
  final Future<void> Function(String token) saveToken;
  final Future<void> Function() clearToken;

  PublicUser? _user;
  PublicUser? get user => _user;
  bool get isLoggedIn => _user != null;

  /// Token tersimpan → `GET /me`. false bila tanpa token, token ditolak,
  /// atau jaringan gagal (pengguna masuk ulang).
  Future<bool> restore() async {
    if (await readToken() == null) return false;
    try {
      _user = await _api.me();
      notifyListeners();
      unawaited(LikedStore.load(_api));
      return true;
    } on ApiException catch (e) {
      if (e.status == 401) await clearToken();
      return false;
    }
  }

  Future<void> signIn(String token, PublicUser user) async {
    await saveToken(token);
    _user = user;
    notifyListeners();
    unawaited(LikedStore.load(_api));
  }

  void setUser(PublicUser user) {
    _user = user;
    notifyListeners();
  }

  /// Dipanggil saat token ditolak server (401) atau keluar.
  void clear() {
    LikedStore.clear();
    if (_user == null) return;
    _user = null;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // sesi server mungkin sudah habis; token lokal tetap dihapus
    }
    await clearToken();
    clear();
  }
}
