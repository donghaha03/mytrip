import 'package:flutter/foundation.dart';

import '../models/country.dart';
import '../models/trip.dart';

/// 프로토타입용 인메모리 저장소.
///
/// 나중에 Firestore를 붙일 때는 이 클래스의 메서드 본문만
/// `users/{uid}/trips/{tripId}` 컬렉션 연동으로 바꾸면 된다.
/// 화면 쪽 코드는 손대지 않아도 되도록 인터페이스를 맞춰 뒀다.
class TripStore extends ChangeNotifier {
  final List<Trip> _trips = [];

  List<Trip> get trips => List.unmodifiable(_trips);
  bool get isEmpty => _trips.isEmpty;

  void add(Trip trip) {
    _trips.add(trip);
    notifyListeners();
  }

  void remove(String id) {
    _trips.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void rename(String id, String newName) {
    final trip = _trips.firstWhere((t) => t.id == id);
    trip.name = newName;
    notifyListeners();
  }

  void addExpense(String tripId, Expense expense) {
    final trip = _trips.firstWhere((t) => t.id == tripId);
    trip.expenses.add(expense);
    notifyListeners();
  }

  /// 00 빈 화면 -> 01 리스트 화면 전환을 눈으로 확인하려면
  /// main.dart 에서 이 함수를 호출해 목업을 채운다.
  void seedMockTrips() {
    if (_trips.isNotEmpty) return;
    final now = DateTime.now();

    final japan = kPrimaryCountries.firstWhere((c) => c.currency == 'JPY');
    final thailand = kPrimaryCountries.firstWhere((c) => c.currency == 'THB');
    final usa = kPrimaryCountries.firstWhere((c) => c.currency == 'USD');

    _trips.addAll([
      // 이미 지난 여행 -> "여행완료" 도장이 찍힌다
      Trip(
        id: 't1',
        name: '미국 여행',
        country: usa,
        start: DateTime(now.year, now.month - 2, 1),
        end: DateTime(now.year, now.month - 2, 10),
        budgetKrw: 2400000,
      ),
      Trip(
        id: 't2',
        name: '일본 여행',
        country: japan,
        start: now.add(const Duration(days: 11)),
        end: now.add(const Duration(days: 15)),
        budgetKrw: 1200000,
        expenses: [
          Expense(
            id: 'e1',
            icon: '🍜',
            category: '식비',
            place: '이치란 라멘',
            amount: 1200,
            date: now.subtract(const Duration(hours: 3)),
          ),
          Expense(
            id: 'e2',
            icon: '🚃',
            category: '교통',
            place: 'JR 패스',
            amount: 3500,
            date: now.subtract(const Duration(days: 1, hours: 2)),
          ),
          Expense(
            id: 'e3',
            icon: '🛍',
            category: '쇼핑',
            place: '돈키호테',
            amount: 2800,
            date: now.subtract(const Duration(days: 1, hours: 6)),
          ),
          Expense(
            id: 'e4',
            icon: '🏨',
            category: '숙소',
            place: '신주쿠 호텔',
            amount: 40600,
            date: now.subtract(const Duration(days: 2)),
          ),
        ],
      ),
      // 이름을 직접 바꾼 여행 (편집 기능 예시)
      Trip(
        id: 't3',
        name: '가족 여행',
        country: thailand,
        start: now.add(const Duration(days: 51)),
        end: now.add(const Duration(days: 56)),
        budgetKrw: 1800000,
      ),
    ]);
  }
}

/// 앱 전역에서 쓰는 단일 인스턴스.
/// provider/riverpod 을 도입하면 이 전역 변수를 걷어내면 된다.
final tripStore = TripStore();
