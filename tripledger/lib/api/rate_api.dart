import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

/// 환율 API
/// - Firestore rates/current 문서에서 환율을 가져옴
/// - 최신 환율은 SharedPreferences에 캐싱
/// - Firestore 호출 실패 시 기존 캐시 사용
/// - 앱 시작 시 main()에서 await RateApi.load() 호출
class RateApi {
  RateApi._();

  static const String _collection = 'rates';
  static const String _document = 'current';

  static Map<String, double> _perKrw = {};

  static DateTime? lastFetched;

  static bool get ready => _perKrw.isNotEmpty;

  /// 원화 1원당 외국 통화 환율을 원화 1단위로 역산
  static double krwPer(String cur) {
    if (cur == 'KRW') return 1;

    final rate = _perKrw[cur];

    return (rate == null || rate == 0) ? 0 : 1 / rate;
  }

  /// 현지 금액 -> 원화
  static double toKrw(double amount, String cur) {
    return amount * krwPer(cur);
  }

  /// 원화 -> 현지 금액
  static double fromKrw(num krw, String cur) {
    final rate = krwPer(cur);

    return rate == 0 ? 0 : krw / rate;
  }

  /// Firestore에서 최신 환율 가져오기
  static Future<void> load({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. 먼저 기존 캐시 불러오기
    final cached = prefs.getString('rates');

    lastFetched = DateTime.tryParse(prefs.getString('rates_time') ?? '');

    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;

        _perKrw = decoded.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
      } catch (_) {
        // 캐시가 손상되었으면 Firestore에서 다시 가져옴
      }
    }

    // 2. Firestore에서 최신 환율 가져오기
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_document)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!snapshot.exists) {
        throw Exception('Firestore 환율 문서가 존재하지 않습니다.');
      }

      final data = snapshot.data();

      if (data == null || data['rates'] is! Map) {
        throw Exception('Firestore 환율 데이터 형식이 올바르지 않습니다.');
      }

      final rawRates = Map<String, dynamic>.from(data['rates']);

      final newRates = <String, double>{};

      for (final currency in currencies) {
        final value = rawRates[currency];

        if (value is num && value > 0) {
          newRates[currency] = value.toDouble();
        }
      }

      if (newRates.isEmpty) {
        throw Exception('사용 가능한 환율 데이터가 없습니다.');
      }

      // 3. 새로운 환율 적용
      _perKrw = newRates;

      // 4. Firestore 업데이트 시간 저장
      final updatedAt = data['lastUpdated'];

      if (updatedAt is Timestamp) {
        lastFetched = updatedAt.toDate();
      } else {
        lastFetched = DateTime.now();
      }

      // 5. SharedPreferences 캐시 갱신
      await prefs.setString('rates', jsonEncode(_perKrw));

      await prefs.setString('rates_time', lastFetched!.toIso8601String());
    } catch (e) {
      // Firestore 호출 실패 시 기존 캐시 유지
      // 캐시도 없다면 ready == false
    }
  }
}
