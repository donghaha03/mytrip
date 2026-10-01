import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/api/api.dart';
import 'package:tripapp/trip_home/models/country.dart';

Map<String, dynamic> responseData(DateTime fetched) => {
  'result': 'success',
  'base_code': 'KRW',
  'rate_date': '2026-09-30',
  'fetched_at': fetched.toIso8601String(),
  'rates': {
    for (final c in [...kPrimaryCountries, ...kMoreCountries])
      c.currency: c.unitAmount / c.krwPerUnit,
    'JPY': 1 / 9,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    RateApi.reset();
    SharedPreferences.setMockInitialValues({});
  });

  test('팀 API 형식·환산 방향·기기 캐시·오류 복구', () async {
    final at = DateTime.utc(2026, 9, 30, 21, 5); // 10/1 06:05 KST
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.host, 'donghaha03.github.io');
      expect(request.url.path, '/mytrip/rates.json');
      return http.Response(jsonEncode(responseData(at)), 200);
    });
    final offline = MockClient((_) async => http.Response('offline', 503));
    addTearDown(() {
      client.close();
      offline.close();
    });

    expect(RateApi.krwPer('UNKNOWN'), 0);
    expect(RateApi.fromKrw(1000, 'UNKNOWN'), 0);
    await Future.wait([
      RateApi.load(client: client, now: at),
      RateApi.load(client: client, now: at),
    ]);
    expect(calls, 1);
    expect(RateApi.krwPer('JPY'), closeTo(9, 1e-9));
    expect(RateApi.krwPer('KRW'), 1);
    expect(RateApi.toKrw(1000, 'JPY'), 9000);
    expect(RateApi.fromKrw(9000, 'JPY'), 1000);
    expect(RateApi.updatedAt, DateTime.utc(2026, 9, 30));
    expect(RateApi.lastFetched, at);
    await RateApi.load(client: client, now: at);
    RateApi.reset();
    await RateApi.load(client: client, now: at);
    expect(calls, 1);
    await RateApi.load(force: true, client: offline, now: at);
    expect(RateApi.hasError, isTrue);
    expect(RateApi.krwPer('JPY'), closeTo(9, 1e-9));
    expect(RateApi.isLoading, isFalse);
    await RateApi.load(force: true, client: client, now: at);
    expect(calls, 2);
    expect(RateApi.hasError, isFalse);
  });

  test('한국 시간 05:59→06:00·자정·월/연도 경계, 배포 지연 재조회', () async {
    final before = DateTime.parse('2026-10-01T20:59:59Z');
    final six = DateTime.parse('2026-10-01T21:00:00Z');
    expect(RateApi.refreshBoundary(before), DateTime.utc(2026, 9, 30, 21));
    expect(RateApi.refreshBoundary(six), six);
    expect(
      RateApi.refreshBoundary(DateTime.parse('2026-10-02T02:00:00+05:00')),
      six,
    );
    expect(
      RateApi.refreshBoundary(DateTime.utc(2026, 10, 1, 15)),
      DateTime.utc(2026, 9, 30, 21),
    );
    expect(
      RateApi.refreshBoundary(DateTime.utc(2027, 1, 1, 20, 59)),
      DateTime.utc(2026, 12, 31, 21),
    );

    var serverFetched = DateTime.utc(2026, 9, 30, 21, 5);
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(jsonEncode(responseData(serverFetched)), 200);
    });
    addTearDown(client.close);
    await RateApi.load(client: client, now: before);
    await RateApi.load(client: client, now: before);
    expect(calls, 1);
    // 24시간이 안 지났어도 06시를 넘으면 재조회. 예전 파일이면 다음에 재시도.
    await RateApi.load(client: client, now: six);
    expect(calls, 2);
    expect(RateApi.lastFetched, serverFetched);
    serverFetched = six.add(const Duration(minutes: 3));
    await RateApi.load(
      client: client,
      now: six.add(const Duration(minutes: 5)),
    );
    await RateApi.load(
      client: client,
      now: six.add(const Duration(minutes: 10)),
    );
    expect(calls, 3);
    expect(RateApi.lastFetched, serverFetched);
  });

  test('손상·0 환율·미래 시각·서버 롤백은 기존 정상 환율 유지', () async {
    final at = DateTime.utc(2026, 10, 1, 21, 5);
    SharedPreferences.setMockInitialValues({
      'mytrip.exchange_rates.v2': 'broken',
    });
    final client = MockClient(
      (_) async => http.Response(jsonEncode(responseData(at)), 200),
    );
    addTearDown(client.close);
    await RateApi.load(client: client, now: at);
    expect(RateApi.ready, isTrue);
    for (final data in [
      responseData(at)..['rates']['JPY'] = 0.0,
      responseData(at.add(const Duration(days: 1))),
      responseData(at.subtract(const Duration(days: 1))),
      responseData(at)..['rate_date'] = '2026-02-30',
    ]) {
      final bad = MockClient((_) async => http.Response(jsonEncode(data), 200));
      await RateApi.load(force: true, client: bad, now: at);
      expect(RateApi.hasError, isTrue);
      expect(RateApi.krwPer('JPY'), closeTo(9, 1e-9));
      expect(RateApi.lastFetched, at);
      bad.close();
    }
    RateApi.reset();
    SharedPreferences.setMockInitialValues({});
    final invalid = responseData(at)..['rates']['JPY'] = 0.0;
    final bad = MockClient(
      (_) async => http.Response(jsonEncode(invalid), 200),
    );
    addTearDown(bad.close);
    await RateApi.load(client: bad, now: at);
    expect(RateApi.ready, isFalse);
    expect(RateApi.krwPer('JPY'), 0);
  });
}
