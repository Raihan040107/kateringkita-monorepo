import '../models/user.dart';
import 'api_client.dart';

extension AuthApi on ApiClient {
  /// `POST /auth/customer/register` → 201 tanpa token; pengguna lalu masuk.
  Future<PublicUser> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final r = await post('/auth/customer/register', body: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'password': password,
    });
    return PublicUser.fromJson(_userOf(r));
  }

  /// `POST /auth/login` dengan email atau nomor HP.
  Future<(String token, PublicUser user)> login(
      String identifier, String password) async {
    final r = await post('/auth/login', body: {
      'identifier': identifier,
      'password': password,
      'client': 'mobile',
    });
    final d = r['data'] as Map<String, dynamic>;
    return ('${d['token']}', PublicUser.fromJson(d['user'] as Map<String, dynamic>));
  }

  Future<void> logout() => post('/auth/logout');

  Future<PublicUser> me() async => PublicUser.fromJson(_userOf(await get('/me')));

  /// `PATCH /me` — kolom: full_name, favorite_pickup_point_id, avatar_url,
  /// email/phone (+ current_password).
  Future<PublicUser> updateMe(Map<String, dynamic> body) async =>
      PublicUser.fromJson(_userOf(await patch('/me', body: body)));

  Future<void> changePassword(String current, String next) => put('/me/password', body: {
        'current_password': current,
        'new_password': next,
      });
}

/// `GET /me` membungkus `{user, merchant}`; endpoint lain mengirim user langsung.
Map<String, dynamic> _userOf(Map<String, dynamic> r) {
  final d = r['data'];
  if (d is Map && d['user'] is Map) return Map<String, dynamic>.from(d['user'] as Map);
  return Map<String, dynamic>.from(d as Map);
}
