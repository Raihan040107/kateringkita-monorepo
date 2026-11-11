import 'json.dart';

class Category {
  const Category({required this.id, required this.name, required this.slug, this.icon});
  final int id;
  final String name;
  final String slug;
  final String? icon;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: asInt(j['id']),
        name: '${j['name'] ?? ''}',
        slug: '${j['slug'] ?? ''}',
        icon: asStringOrNull(j['icon']),
      );
}

class PickupPoint {
  const PickupPoint({required this.id, required this.name, this.description});
  final int id;
  final String name;
  final String? description;

  factory PickupPoint.fromJson(Map<String, dynamic> j) => PickupPoint(
        id: asInt(j['id']),
        name: '${j['name'] ?? ''}',
        description: asStringOrNull(j['description']),
      );
}

class AppSettings {
  const AppSettings({required this.serviceFee, required this.timezone, this.csWhatsapp});
  final int serviceFee;
  final String timezone;
  final String? csWhatsapp;

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        serviceFee: asInt(j['service_fee']),
        timezone: '${j['timezone'] ?? 'Asia/Jakarta'}',
        csWhatsapp: asStringOrNull(j['cs_whatsapp']),
      );
}
