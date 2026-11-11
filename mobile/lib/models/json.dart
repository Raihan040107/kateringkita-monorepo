/// Pembaca JSON toleran: angka bisa datang sebagai num atau string desimal
/// (DECIMAL MySQL), waktu sebagai ISO UTC.
int asInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return (double.tryParse(v) ?? fallback).toInt();
  return fallback;
}

int? asIntOrNull(dynamic v) => v == null ? null : asInt(v);

double asDouble(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

bool asBool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

String? asStringOrNull(dynamic v) =>
    v == null || (v is String && v.isEmpty) ? null : '$v';

DateTime? asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse('$v');
}

Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> asList(dynamic v) =>
    v is List ? v.map(asMap).toList() : const [];
