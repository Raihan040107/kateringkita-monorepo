import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token sesi API disimpan terenkripsi: Keychain (iOS) / Keystore (Android).
class TokenStore {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'access_token';
  // Sisa skema lama; hanya dibaca SettingsStore. Hapus bersama settings_store.dart.
  static const _sessionEmailKey = 'session_email';

  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> readToken() => _storage.read(key: _tokenKey);

  static Future<String?> readSessionEmail() =>
      _storage.read(key: _sessionEmailKey);

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _sessionEmailKey);
  }
}
