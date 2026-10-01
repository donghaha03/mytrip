import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../trip_home/models/country.dart';

/// 팀 RateApi와 같은 호출 형식. mytrip의 06시(KST) 서버 스냅샷을 읽는다.
class RateApi {
  RateApi._();
  static const _cacheKey = 'mytrip.exchange_rates.v2';
  static final _url = Uri.parse(
    'https://donghaha03.github.io/mytrip/rates.json',
  );
  static final changes = ValueNotifier<int>(0);

  static Map<String, double> _perKrw = {};
  static DateTime? lastFetched;
  static DateTime? updatedAt;
  static bool isLoading = false;
  static bool hasError = false;

  static bool get ready => _perKrw.isNotEmpty;
  static bool get isStale => !_fresh(DateTime.now());

  /// 팀과 동일: 1 현지 통화 = 몇 원. 정보가 없으면 0.
  static double krwPer(String currency) {
    if (currency == 'KRW') return 1;
    final value = _perKrw[currency];
    return value == null ? 0 : 1 / value;
  }

  static double toKrw(double amount, String currency) =>
      amount * krwPer(currency);

  static double fromKrw(num krw, String currency) {
    final rate = krwPer(currency);
    return rate == 0 ? 0 : krw / rate;
  }

  /// 기기 시간대와 무관하게 가장 최근 한국 시간 오전 6시(UTC 반환).
  static DateTime refreshBoundary(DateTime at) {
    final kst = at.toUtc().add(const Duration(hours: 9));
    final six = DateTime.utc(
      kst.year,
      kst.month,
      kst.day,
      6,
    ).subtract(const Duration(hours: 9));
    return kst.hour < 6 ? six.subtract(const Duration(days: 1)) : six;
  }

  static bool _fresh(DateTime now) =>
      ready &&
      lastFetched != null &&
      !lastFetched!.isBefore(refreshBoundary(now)) &&
      !lastFetched!.isAfter(now);

  static Future<void> load({
    bool force = false,
    http.Client? client,
    DateTime? now,
  }) async {
    if (isLoading) return;
    final clock = (now ?? DateTime.now()).toUtc();
    if (!force && _fresh(clock)) return;
    isLoading = true;
    hasError = false;
    changes.value++;
    try {
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_cacheKey);
        if (!ready && cached != null) {
          final entry = jsonDecode(cached) as Map<String, dynamic>;
          final parsed = _parse(entry, clock);
          _perKrw = parsed.rates;
          updatedAt = parsed.updated;
          lastFetched = parsed.fetched;
        }
      } catch (e) {
        // 캐시가 손상됐거나 저장소가 차단돼도 API 조회는 시도한다.
        debugPrint('[RateApi] 캐시 읽기 실패: $e');
      }

      if (!force && _fresh(clock)) return;

      final url = _url.replace(
        queryParameters: {'t': '${clock.millisecondsSinceEpoch}'},
      );
      final response = await (client?.get(url) ?? http.get(url)).timeout(
        const Duration(seconds: 6),
      );
      if (response.statusCode != 200) {
        throw FormatException('HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body);
      final parsed = _parse(data, clock);
      if (lastFetched != null && parsed.fetched.isBefore(lastFetched!)) {
        throw const FormatException('이전 환율 응답으로 되돌리지 않습니다');
      }
      _perKrw = parsed.rates;
      updatedAt = parsed.updated;
      // 기기 조회 시각이 아니라 서버 갱신 시각. 06시 배포가 늦으면 재조회한다.
      lastFetched = parsed.fetched;
      try {
        await prefs?.setString(_cacheKey, jsonEncode(data));
      } catch (e) {
        debugPrint('[RateApi] 캐시 저장 실패: $e');
      }
    } catch (e) {
      hasError = true;
      debugPrint('[RateApi] 환율 조회 실패: $e');
    } finally {
      isLoading = false;
      changes.value++;
    }
  }

  static ({Map<String, double> rates, DateTime updated, DateTime fetched})
  _parse(dynamic data, DateTime now) {
    if (data is! Map<String, dynamic> ||
        data['result'] != 'success' ||
        data['base_code'] != 'KRW') {
      throw const FormatException('KRW 기준 환율 응답이 아닙니다');
    }
    final raw = data['rates'] as Map<String, dynamic>;
    final rates = <String, double>{'KRW': 1};
    for (final country in [...kPrimaryCountries, ...kMoreCountries]) {
      final value = raw[country.currency];
      if (value is! num ||
          !value.isFinite ||
          value <= 0 ||
          !(1 / value).isFinite) {
        throw FormatException('${country.currency} 환율이 올바르지 않습니다');
      }
      rates[country.currency] = value.toDouble();
    }
    final date = data['rate_date'];
    if (date is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      throw const FormatException('환율 기준일이 없습니다');
    }
    final updated = DateTime.parse('${date}T00:00:00Z');
    final fetched = DateTime.parse(data['fetched_at'] as String).toUtc();
    if (updated.toIso8601String().substring(0, 10) != date ||
        updated.isAfter(fetched) ||
        fetched.isAfter(now)) {
      throw const FormatException('환율 기준일 또는 갱신 시각이 올바르지 않습니다');
    }
    return (rates: rates, updated: updated, fetched: fetched);
  }

  @visibleForTesting
  static void reset() {
    _perKrw = {};
    lastFetched = null;
    updatedAt = null;
    isLoading = false;
    hasError = false;
  }
}
