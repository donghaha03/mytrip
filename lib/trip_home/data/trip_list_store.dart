import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../api/api.dart' as api;
import '../../ledger/data/trip_store.dart';
import '../../ledger/models/trip.dart';

/// 여행 목록 화면의 상태. 읽기는 팀 API(`TripApi.watchAll`)만 쓴다.
///
/// 여행마다 장부와 같은 [TripStore]를 하나씩 두어 목록·여행 홈·장부가 같은 값을
/// 보고, 여행을 열 때 그 스토어를 그대로 넘긴다.
class TripListStore extends ChangeNotifier {
  TripListStore({
    Stream<List<api.Trip>> Function()? watchTrips,
    TripStore Function(String tripId)? storeFor,
  }) : _watchTrips = watchTrips ?? api.TripApi.watchAll,
       _storeFor = storeFor ?? ((id) => TripStore(tripId: id)) {
    _listen();
  }

  final Stream<List<api.Trip>> Function() _watchTrips;
  final TripStore Function(String tripId) _storeFor;
  StreamSubscription<List<api.Trip>>? _sub;
  final _stores = <String, TripStore>{};
  List<String> _order = const [];
  bool _ready = false, _disposed = false;

  /// 목록 구독 오류. 화면에서 `AuthApi.errorMessage`로 보여준다.
  Object? error;

  /// 첫 목록과 각 여행의 지출이 올 때까지. 이때 빈 화면을 띄우면 여행이 있는
  /// 사용자에게도 첫 화면이 잠깐 보인다.
  bool get isLoading =>
      error == null &&
      (!_ready || _stores.values.any((s) => s.isLoading && s.error == null));

  /// 열 수 있는 여행의 스토어 (최근 시작일 순).
  List<TripStore> get stores => [
    for (final id in _order)
      if (_stores[id]?.trip != null) _stores[id]!,
  ];
  List<Trip> get trips => [for (final s in stores) s.trip!];
  bool get isEmpty => stores.isEmpty;

  void _listen() {
    _sub = _watchTrips().listen(
      (list) {
        if (_disposed) return;
        final ids = {for (final t in list) t.id};
        for (final id in _stores.keys.toList()) {
          if (!ids.contains(id)) _drop(_stores.remove(id)!);
        }
        for (final id in ids) {
          _stores.putIfAbsent(
            id,
            () => _storeFor(id)..addListener(notifyListeners),
          );
        }
        _order = [for (final t in list) t.id];
        _ready = true;
        error = null;
        notifyListeners();
      },
      onError: (Object e) {
        if (_disposed) return;
        error = e;
        notifyListeners();
      },
    );
  }

  void _drop(TripStore store) => store
    ..removeListener(notifyListeners)
    ..dispose();

  /// 구독 오류 뒤 다시 시도.
  void retry() {
    unawaited(_sub?.cancel());
    error = null;
    notifyListeners();
    _listen();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    _stores.values.forEach(_drop);
    _stores.clear();
    super.dispose();
  }
}
