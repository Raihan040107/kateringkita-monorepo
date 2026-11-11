import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/services/api_client.dart';

ApiClient klien(
  Future<http.Response> Function(http.Request) handler, {
  String? token,
  void Function()? onUnauthenticated,
}) =>
    ApiClient(
      MockClient(handler),
      readToken: () async => token,
      onUnauthenticated: onUnauthenticated,
      baseUrl: 'http://api.test/v1',
    );

http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test('mengembalikan body {data} dan {data, meta} apa adanya', () async {
    final api = klien((_) async => json({
          'data': [1, 2],
          'meta': {'page': 1, 'limit': 20, 'total': 2}
        }));
    final r = await api.get('/menus');
    expect(r['data'], [1, 2]);
    expect(r['meta']['total'], 2);
  });

  test('204 tanpa body → map kosong', () async {
    final api = klien((_) async => http.Response('', 204));
    expect(await api.delete('/me/favorites/1'), isEmpty);
  });

  test('galat → ApiException dengan code, message, fields', () async {
    final api = klien((_) async => json({
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Data tidak valid.',
            'fields': {'phone': ['Nomor HP tidak valid.']}
          }
        }, 400));
    try {
      await api.post('/auth/customer/register', body: {});
      fail('harus melempar');
    } on ApiException catch (e) {
      expect(e.status, 400);
      expect(e.code, 'VALIDATION_ERROR');
      expect(e.message, 'Data tidak valid.');
      expect(e.field('phone'), 'Nomor HP tidak valid.');
      expect(e.field('email'), isNull);
    }
  });

  test('body bukan JSON (mis. HTML 502) tetap jadi ApiException', () async {
    final api = klien((_) async => http.Response('<html>Bad Gateway</html>', 502));
    expect(
      () => api.get('/health'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 502)),
    );
  });

  test('401 dengan token memanggil onUnauthenticated', () async {
    var dipanggil = 0;
    final api = klien(
      (_) async => json({'error': {'code': 'UNAUTHENTICATED', 'message': 'x'}}, 401),
      token: 'tok',
      onUnauthenticated: () => dipanggil++,
    );
    await expectLater(api.get('/me'), throwsA(isA<ApiException>()));
    expect(dipanggil, 1);
  });

  test('401 tanpa token (sandi salah) tidak memanggil onUnauthenticated', () async {
    var dipanggil = 0;
    final api = klien(
      (_) async => json({'error': {'code': 'UNAUTHENTICATED', 'message': 'Sandi salah'}}, 401),
      onUnauthenticated: () => dipanggil++,
    );
    await expectLater(api.post('/auth/login', body: {}), throwsA(isA<ApiException>()));
    expect(dipanggil, 0);
  });

  test('header bearer, JSON, Idempotency-Key; query null dibuang', () async {
    late http.Request terkirim;
    final api = klien((req) async {
      terkirim = req;
      return json({'data': {}});
    }, token: 'tok');
    await api.post('/orders', body: {'a': 1}, headers: {'Idempotency-Key': 'k'});
    expect(terkirim.headers['Authorization'], 'Bearer tok');
    expect(terkirim.headers['Content-Type'], startsWith('application/json'));
    expect(terkirim.headers['Idempotency-Key'], 'k');
    expect(terkirim.body, '{"a":1}');

    await api.get('/menus', query: {'q': null, 'category': '', 'page': '2'});
    expect(terkirim.url.toString(), 'http://api.test/v1/menus?page=2');
    expect(terkirim.method, 'GET');
  });

  test('galat jaringan → status 0 NETWORK', () async {
    final api = klien((_) async => throw http.ClientException('putus'));
    expect(
      () => api.get('/menus'),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 0)
          .having((e) => e.code, 'code', 'NETWORK')),
    );
  });

  test('uuidV4 berformat v4 huruf kecil dan unik', () {
    final re = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final a = uuidV4();
    final b = uuidV4();
    expect(re.hasMatch(a), isTrue, reason: a);
    expect(re.hasMatch(b), isTrue, reason: b);
    expect(a, isNot(b));
  });
}
