import 'json.dart';

/// Pengguna dari `GET /me` / `POST /auth/login`.
class PublicUser {
  const PublicUser({
    required this.id,
    required this.role,
    required this.fullName,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.favoritePickupPointId,
  });

  final int id;
  final String role;
  final String fullName;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final int? favoritePickupPointId;

  factory PublicUser.fromJson(Map<String, dynamic> j) => PublicUser(
        id: asInt(j['id']),
        role: '${j['role'] ?? 'customer'}',
        fullName: '${j['full_name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        email: asStringOrNull(j['email']),
        avatarUrl: asStringOrNull(j['avatar_url']),
        favoritePickupPointId: asIntOrNull(j['favorite_pickup_point_id']),
      );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final chars = parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0]);
    return chars.join().toUpperCase();
  }
}
