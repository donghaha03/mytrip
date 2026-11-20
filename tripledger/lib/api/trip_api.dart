import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trip.dart';
import 'paths.dart';

/// 여행 CRUD
class TripApi {
  TripApi._();

  static CollectionReference<Map<String, dynamic>> get _col => Paths.trips;

  /// 내 여행 목록 (최근 시작일 순, 실시간)
  static Stream<List<Trip>> watchAll() => _col
      .orderBy('start', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Trip.fromDoc).toList());

  /// 여행 1개 (실시간). 삭제되었거나 없으면 null
  static Stream<Trip?> watch(String tripId) => _col
      .doc(tripId)
      .snapshots()
      .map((s) => s.exists ? Trip.fromDoc(s) : null);

  /// 여행 1개 (한 번만 읽기)
  static Future<Trip?> get(String tripId) async {
    final s = await _col.doc(tripId).get();
    return s.exists ? Trip.fromDoc(s) : null;
  }

  /// 여행 추가. 생성된 tripId 반환
  static Future<String> add({
    required String name,
    required int budget,
    required String currency,
    required DateTime start,
    required DateTime end,
  }) async {
    final ref = await _col.add(
      Trip(
        id: '',
        name: name.trim(),
        budget: budget,
        currency: currency,
        start: start,
        end: end,
      ).toMap(),
    );
    return ref.id;
  }

  /// 여행 수정 (이름/예산/기간 등)
  static Future<void> update(Trip trip) =>
      _col.doc(trip.id).update(trip.toMap());

  /// 예산만 변경
  static Future<void> updateBudget(String tripId, int budget) =>
      _col.doc(tripId).update({'budget': budget});

  /// 여행 삭제 (하위 지출 내역도 함께 삭제)
  static Future<void> delete(String tripId) async {
    final exp = await _col.doc(tripId).collection('expenses').get();
    for (var i = 0; i < exp.docs.length; i += 400) {
      final batch = FirebaseFirestore.instance.batch();
      for (final d in exp.docs.skip(i).take(400)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await _col.doc(tripId).delete();
  }

  /// 내 모든 여행 삭제 (회원 탈퇴 시 사용)
  static Future<void> deleteAll() async {
    final trips = await _col.get();
    for (final t in trips.docs) {
      await delete(t.id);
    }
  }
}
