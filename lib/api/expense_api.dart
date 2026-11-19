import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense.dart';
import 'api_exception.dart';
import 'paths.dart';
import 'rate_api.dart';

/// 지출 CRUD
class ExpenseApi {
  ExpenseApi._();

  static CollectionReference<Map<String, dynamic>> _col(String tripId) =>
      Paths.expenses(tripId);

  /// 지출 목록 (최근 결제가 위로, 실시간)
  static Stream<List<Expense>> watchAll(String tripId) =>
      _col(tripId)
          .orderBy('date', descending: true)
          .snapshots()
          .map((s) => s.docs.map(Expense.fromDoc).toList());

  /// 지출 추가. 날짜는 지금 시각, 환율은 현재 환율이 자동 적용됩니다.
  /// 환율 정보가 없으면 [ApiException]
  static Future<void> add(
    String tripId, {
    required String category,
    required String place,
    required double amount,
    required String currency,
    DateTime? date,
  }) async {
    final rate = RateApi.krwPer(currency);
    if (rate <= 0) {
      throw const ApiException('환율 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
    }
    await _col(tripId).add(
      Expense(
        id: '',
        category: category,
        place: place.trim(),
        amount: amount,
        currency: currency,
        rate: rate,
        date: date ?? DateTime.now(),
      ).toMap(),
    );
  }

  /// 지출 수정. 저장 당시 환율/날짜는 expense에 들어있는 값 그대로 유지됩니다.
  /// (현재 환율로 다시 계산하려면 expense.copyWith(rate: RateApi.krwPer(...)))
  static Future<void> update(String tripId, Expense expense) =>
      _col(tripId).doc(expense.id).update(expense.toMap());

  static Future<void> delete(String tripId, String expenseId) =>
      _col(tripId).doc(expenseId).delete();

  /// 삭제 취소(되돌리기)용: 같은 ID로 복원
  static Future<void> restore(String tripId, Expense expense) =>
      _col(tripId).doc(expense.id).set(expense.toMap());
}
