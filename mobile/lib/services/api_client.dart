import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';

/// Galat dari API: `{error:{code,message,fields?}}`, atau status 0 bila
/// jaringan putus.
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message,
      [this.fields = const {}]);

  final int status;
  final String code;
  final String message;
  final Map<String, List<String>> fields;

  /// Pesan pertama untuk satu kolom, mis. `field('promo_code')`.
  String? field(String name) {
    final list = fields[name];
    return (list == null || list.isEmpty) ? null : list.first;
  }

  bool get isNetwork => status == 0;

  @override
  String toString() => message;
}

typedef TokenReader = Future<String?> Function();

/// Klien HTTP tipis: bearer token, JSON, pemetaan galat, timeout 20 detik.
/// Semua metode mengembalikan body ter-decode (`{data, meta}`); 204 → `{}`.
class ApiClient {
  ApiClient(
    this._http, {
    required this.readToken,
    this.onUnauthenticated,
    this.baseUrl = apiBaseUrl,
  });

  final http.Client _http;
  final TokenReader readToken;

  /// Dipanggil saat server menjawab 401 untuk permintaan yang membawa token
  /// (token kedaluwarsa/dicabut). 401 tanpa token (sandi salah) tidak memicu.
  final void Function()? onUnauthenticated;
  final String baseUrl;

  static const timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> get(String path,
          {Map<String, String?>? query}) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(String path,
          {Object? body, Map<String, String>? headers}) =>
      _send('POST', path, body: body ?? const {}, headers: headers);

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body ?? const {});

  Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _send('PUT', path, body: body ?? const {});

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Uri _uri(String path, Map<String, String?>? query) {
    final uri = Uri.parse('$baseUrl$path');
    final q = <String, String>{
      ...uri.queryParameters,
      if (query != null)
        for (final e in query.entries)
          if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    return q.isEmpty ? uri : uri.replace(queryParameters: q);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String?>? query,
    Object? body,
    Map<String, String>? headers,
  }) async {
    final token = await readToken();
    final req = http.Request(method, _uri(path, query));
    req.headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (headers != null) req.headers.addAll(headers);
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    http.Response res;
    try {
      res = await http.Response.fromStream(
          await _http.send(req).timeout(timeout));
    } catch (_) {
      throw ApiException(0, 'NETWORK', 'Tidak dapat terhubung ke server.');
    }

    dynamic decoded;
    if (res.bodyBytes.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        decoded = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      return decoded == null ? <String, dynamic>{} : {'data': decoded};
    }

    final err = decoded is Map ? decoded['error'] : null;
    final fields = <String, List<String>>{};
    if (err is Map && err['fields'] is Map) {
      for (final e in (err['fields'] as Map).entries) {
        final v = e.value;
        fields['${e.key}'] =
            v is List ? v.map((x) => '$x').toList() : ['$v'];
      }
    }
    if (res.statusCode == 401 && token != null) onUnauthenticated?.call();
    throw ApiException(
      res.statusCode,
      err is Map ? '${err['code'] ?? 'HTTP_${res.statusCode}'}' : 'HTTP_${res.statusCode}',
      err is Map && err['message'] != null
          ? '${err['message']}'
          : 'Terjadi gangguan (${res.statusCode}). Coba lagi.',
      fields,
    );
  }
}

/// UUID v4 acak untuk header `Idempotency-Key` (backend memvalidasi format).
String uuidV4() {
  final rnd = Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
