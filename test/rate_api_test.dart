import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/trip_home/models/country.dart';
import 'package:tripapp/trip_home/services/rate_api.dart';

Map<String, dynamic> responseData() => {
  'result': 'success',
  'base_code': 'KRW',
  'time_last_update_unix': 1790812951,
  'rates': {
    for (final c in [...kPrimaryCountries, ...kMoreCountries])
      c.currency: c.unitAmount / c.krwPerUnit,
    'JPY': 1 / 9,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('환율 방향·제공 기준 시각·24시간 캐시와 실패 시 복구', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.toString(), 'https://open.er-api.com/v6/latest/KRW');
      return http.Response(jsonEncode(responseData()), 200);
    });
    final api = RateApi();
    final restored = RateApi();
    final offline = MockClient((_) async => http.Response('연결 실패', 503));
    addTearDown(() {
      client.close();
      offline.close();
      api.dispose();
      restored.dispose();
    });

    await Future.wait([api.load(client: client), api.load(client: client)]);
    expect(calls, 1);
    expect(api.krwPer('JPY'), closeTo(9, 1e-9));
    expect(api.krwPer('KRW'), 1);
    expect(api.krwPer('UNKNOWN'), isNull);
    expect(
      api.updatedAt,
      DateTime.fromMillisecondsSinceEpoch(1790812951000, isUtc: true),
    );
    expect(api.hasError, isFalse);
    await api.load(client: client);
    await restored.load(client: client);
    expect(calls, 1); // 메모리와 기기 캐시 모두 불필요한 재호출을 막는다.
    expect(restored.krwPer('JPY'), closeTo(9, 1e-9));

    await restored.load(force: true, client: offline);
    expect(restored.hasError, isTrue);
    expect(restored.isLoading, isFalse);
    expect(restored.krwPer('JPY'), closeTo(9, 1e-9));
    await restored.load(force: true, client: client);
    expect(calls, 2);
    expect(restored.hasError, isFalse);
  });

  test('24시간 지난 캐시는 API를 다시 조회한다', () async {
    final api = RateApi();
    final client = MockClient(
      (_) async => http.Response(jsonEncode(responseData()), 200),
    );
    addTearDown(() {
      api.dispose();
      client.close();
    });
    await api.load(client: client);
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().single;
    final cached = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
    cached['fetched_at'] = DateTime.now()
        .subtract(const Duration(hours: 25))
        .toIso8601String();
    await prefs.setString(key, jsonEncode(cached));
    var calls = 0;
    final fresh = RateApi();
    final newClient = MockClient((_) async {
      calls++;
      return http.Response(jsonEncode(responseData()), 200);
    });
    addTearDown(() {
      fresh.dispose();
      newClient.close();
    });
    await fresh.load(client: newClient);
    expect(calls, 1);
    expect(fresh.ready, isTrue);
  });

  test('캐시 손상은 재조회하고 잘못된 환율은 계산에 쓰지 않는다', () async {
    SharedPreferences.setMockInitialValues({
      'mytrip.exchange_rates.v1': 'broken',
    });
    final api = RateApi();
    final client = MockClient(
      (_) async => http.Response(jsonEncode(responseData()), 200),
    );
    final invalid = responseData();
    (invalid['rates'] as Map<String, dynamic>)['JPY'] = 0;
    final bad = MockClient(
      (_) async => http.Response(jsonEncode(invalid), 200),
    );
    final cold = RateApi();
    addTearDown(() {
      api.dispose();
      cold.dispose();
      client.close();
      bad.close();
    });
    await api.load(client: client);
    expect(api.ready, isTrue);
    await api.load(force: true, client: bad);
    expect(api.hasError, isTrue);
    expect(api.krwPer('JPY'), closeTo(9, 1e-9));

    SharedPreferences.setMockInitialValues({});
    await cold.load(client: bad);
    expect(cold.hasError, isTrue);
    expect(cold.ready, isFalse);
    expect(cold.krwPer('JPY'), isNull);
  });
}
