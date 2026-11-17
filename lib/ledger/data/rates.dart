import 'package:flutter/foundation.dart';

import '../../api/api.dart' as api;
import '../models/country.dart';

/// 기존 장부의 정수 표시를 팀 공용 환율 데이터에 연결한다.
class RateApi {
  RateApi._();
  static final changes = ValueNotifier<int>(0);
  static bool isLoading = false;
  static bool hasError = false;
  static bool get ready => api.RateApi.ready;
  static DateTime? get lastFetched => api.RateApi.lastFetched;
  static bool get isStale {
    final last = lastFetched;
    final now = DateTime.now();
    return last == null ||
        last.year != now.year ||
        last.month != now.month ||
        last.day != now.day;
  }

  static double krwPer(String code) => api.RateApi.krwPer(code);
  static int quotedKrw(String code) =>
      (krwPer(code) * (countryByCode(code)?.unitAmount ?? 1)).truncate();
  static int toKrw(num amount, String code) =>
      api.RateApi.toKrw(amount.toDouble(), code).truncate();
  static int fromKrw(num amount, String code) =>
      api.RateApi.fromKrw(amount, code).truncate();

  static Future<void> load({bool force = false}) async {
    if (isLoading) return;
    isLoading = true;
    changes.value++;
    try {
      await api.RateApi.load(force: force);
      hasError = !ready || isStale;
    } catch (_) {
      hasError = true;
    } finally {
      isLoading = false;
      changes.value++;
    }
  }
}
