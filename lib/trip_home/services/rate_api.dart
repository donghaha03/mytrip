import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/country.dart';

/// 팀과 같은 KRW 기준 API를 사용한다. 캐시는 기기에만 저장한다.
class RateApi extends ChangeNotifier {
  static const _cacheKey = 'mytrip.exchange_rates.v1';
  static final _url = Uri.parse('https://open.er-api.com/v6/latest/KRW');

  Map<String, double> _perKrw = {};
  DateTime? lastFetched;
  DateTime? updatedAt;
  bool isLoading = false;
  bool hasError = false;

  bool get ready => _perKrw.isNotEmpty;

  /// 1 현지 통화 = 몇 원. 정보가 없으면 계산하지 않는다.
  double? krwPer(String currency) {
    final value = _perKrw[currency];
    return value == null ? null : 1 / value;
  }

  Future<void> load({bool force = false, http.Client? client}) async {
    if (isLoading) return;
    isLoading = true;
    hasError = false;
    notifyListeners();
    try {
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_cacheKey);
        if (!ready && cached != null) {
          final entry = jsonDecode(cached) as Map<String, dynamic>;
          final fetched = DateTime.parse(entry['fetched_at'] as String);
          final parsed = _parse(entry['data']);
          _perKrw = parsed.rates;
          updatedAt = parsed.updated;
          lastFetched = fetched;
        }
      } catch (e) {
        // 캐시가 손상됐거나 저장소가 차단돼도 API 조회는 시도한다.
        debugPrint('[RateApi] 캐시 읽기 실패: $e');
      }

      final age = lastFetched == null
          ? null
          : DateTime.now().difference(lastFetched!);
      if (!force &&
          ready &&
          age != null &&
          age >= Duration.zero &&
          age < const Duration(hours: 24)) {
        return;
      }

      final response = await (client?.get(_url) ?? http.get(_url)).timeout(
        const Duration(seconds: 6),
      );
      if (response.statusCode != 200) {
        throw FormatException('HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body);
      final parsed = _parse(data);
      _perKrw = parsed.rates;
      updatedAt = parsed.updated;
      lastFetched = DateTime.now();
      try {
        await prefs?.setString(
          _cacheKey,
          jsonEncode({
            'fetched_at': lastFetched!.toIso8601String(),
            'data': data,
          }),
        );
      } catch (e) {
        debugPrint('[RateApi] 캐시 저장 실패: $e');
      }
    } catch (e) {
      hasError = true;
      debugPrint('[RateApi] 환율 조회 실패: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  ({Map<String, double> rates, DateTime updated}) _parse(dynamic data) {
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
    final seconds = data['time_last_update_unix'];
    if (seconds is! int || seconds <= 0) {
      throw const FormatException('환율 기준 시각이 없습니다');
    }
    return (
      rates: rates,
      updated: DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
    );
  }
}

final rateApi = RateApi();
