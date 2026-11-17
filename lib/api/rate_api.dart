import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

/// 환율 API
/// - 마지막 호출 날짜를 저장해서, 오늘 이미 불렀다면 다시 호출하지 않음
/// - 호출 실패 시 이전에 저장된 값으로 계속 동작
/// - 앱 시작 시 main()에서 `await RateApi.load();` 한 번만 호출
class RateApi {
  RateApi._();

  // 무키 환율 API (KRW 기준). API를 바꾸려면 load() 안의 파싱만 수정하세요.
  static const _url = 'https://open.er-api.com/v6/latest/KRW';

  static Map<String, double> _perKrw = {}; // 1 KRW = x 통화
  static DateTime? lastFetched;

  static bool get ready => _perKrw.isNotEmpty;

  static double krwPer(String cur) {
    if (cur == 'KRW') return 1;
    final r = _perKrw[cur];
    return (r == null || r == 0) ? 0 : 1 / r;
  }

  /// 현지 금액 -> 원화
  static double toKrw(double amount, String cur) => amount * krwPer(cur);

  /// 원화 -> 현지 금액 (환율 정보 없으면 0)
  static double fromKrw(num krw, String cur) {
    final r = krwPer(cur);
    return r == 0 ? 0 : krw / r;
  }

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// [force]=true면 오늘 이미 호출했어도 다시 호출
  static Future<void> load({bool force = false}) async {
    final p = await SharedPreferences.getInstance();
    final cached = p.getString('rates');
    lastFetched = DateTime.tryParse(p.getString('rates_time') ?? '');
    if (cached != null) {
      final m = jsonDecode(cached) as Map<String, dynamic>;
      _perKrw = m.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    final fresh =
        ready &&
        lastFetched != null &&
        _dayKey(lastFetched!) == _dayKey(DateTime.now());
    if (fresh && !force) return; // 오늘 이미 호출함

    try {
      final res = await http
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) throw Exception('status ${res.statusCode}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['result'] != 'success') throw Exception('result fail');
      final rates = data['rates'] as Map<String, dynamic>;
      _perKrw = {
        for (final c in currencies)
          if (rates[c] != null) c: (rates[c] as num).toDouble(),
      };
      lastFetched = DateTime.now();
      await p.setString('rates', jsonEncode(_perKrw));
      await p.setString('rates_time', lastFetched!.toIso8601String());
    } catch (_) {
      // 실패해도 캐시된 값으로 계속 동작
    }
  }
}
