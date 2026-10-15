import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense.dart';
import '../models/receipt_item.dart';
import '../constants.dart';
import 'api_exception.dart';
import 'paths.dart';
import 'rate_api.dart';

/// 지출 CRUD
class ExpenseApi {
  ExpenseApi._();

  static CollectionReference<Map<String, dynamic>> _col(String tripId) =>
      Paths.expenses(tripId);

  /// 입력 화면이 재시도해도 중복 기록을 만들지 않도록 ID를 먼저 발급한다.
  static String newId(String tripId) => _col(tripId).doc().id;

  /// 장부의 영수증/메모를 포함한 저장. 기존 문서의 다른 파트 필드는 보존한다.
  static Future<void> save(String tripId, Expense expense) {
    validate(expense);
    return _col(tripId)
        .doc(expense.id)
        .set(expense.toMap(), SetOptions(merge: true));
  }

  static void validate(Expense expense) {
    if (expense.id.isEmpty ||
        expense.id.contains('/') ||
        expense.place.trim().isEmpty ||
        !categoryIcons.containsKey(expense.category) ||
        !expense.amount.isFinite ||
        expense.amount < 0 ||
        (expense.status.countsAsSpending && expense.amount <= 0) ||
        !expense.rate.isFinite ||
        expense.rate <= 0 ||
        !(expense.amount * expense.rate).isFinite ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(expense.currency) ||
        expense.memo.length > 300 ||
        (expense.originalAmount != null &&
            (!expense.originalAmount!.isFinite ||
                expense.originalAmount! < 0)) ||
        (expense.receiptAdjustments != null &&
            ReceiptAdjustments.fromJson(expense.receiptAdjustments!.toJson()) ==
                null) ||
        expense.receiptTaxes.length > 10 ||
        expense.receiptTaxes.any(
          (tax) => ReceiptTax.fromJson(tax.toJson()) == null,
        ) ||
        expense.receiptItems.length > 100 ||
        expense.receiptItems.any(
          (item) => ReceiptItem.fromJson(item.toJson()) == null,
        )) {
      throw const ApiException('사용처·금액·환율과 영수증 정보를 확인해주세요');
    }
  }

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
    await save(
      tripId,
      Expense(
        id: newId(tripId),
        category: category,
        place: place.trim(),
        amount: amount,
        currency: currency,
        rate: rate,
        date: date ?? DateTime.now(),
      ),
    );
  }

  /// 지출 수정. 저장 당시 환율/날짜는 expense에 들어있는 값 그대로 유지됩니다.
  /// (현재 환율로 다시 계산하려면 expense.copyWith(rate: RateApi.krwPer(...)))
  static Future<void> update(String tripId, Expense expense) {
    validate(expense);
    return _col(tripId).doc(expense.id).update(expense.toMap());
  }

  static Future<void> delete(String tripId, String expenseId) =>
      _col(tripId).doc(expenseId).delete();

  /// 삭제 취소(되돌리기)용: 같은 ID로 복원
  static Future<void> restore(String tripId, Expense expense) =>
      save(tripId, expense);
}
