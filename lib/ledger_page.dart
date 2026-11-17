import 'package:flutter/material.dart';

import 'api/api.dart';
import 'ledger/data/rates.dart' as ledger;
import 'ledger/data/trip_store.dart';
import 'ledger/screens/ledger_screen.dart';
import 'ledger/theme/app_theme.dart';
import 'ledger/widgets/screen_top_bar.dart';

/// 선택한 여행의 장부. 로그인과 여행 선택은 호출 화면에서 담당한다.
/// LedgerPage(tripId: trip.id)로 연다.
class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key, required this.tripId, this.onMore});
  final String tripId;
  final VoidCallback? onMore;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  late final _users = AuthApi.userChanges;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _users,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _Notice(message: AuthApi.errorMessage(snapshot.error!));
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _Notice();
      }
      if (snapshot.data == null) {
        return const _Notice(message: '로그인 후 여행 장부를 열어주세요');
      }
      return _ConnectedLedger(
        key: ValueKey('${snapshot.data!.uid}/${widget.tripId}'),
        tripId: widget.tripId,
        onMore: widget.onMore,
      );
    },
  );
}

class _ConnectedLedger extends StatefulWidget {
  const _ConnectedLedger({super.key, required this.tripId, this.onMore});
  final String tripId;
  final VoidCallback? onMore;

  @override
  State<_ConnectedLedger> createState() => _ConnectedLedgerState();
}

class _ConnectedLedgerState extends State<_ConnectedLedger> {
  late TripStore _store;

  @override
  void initState() {
    super.initState();
    _store = TripStore(tripId: widget.tripId);
    ledger.RateApi.load();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: buildAppTheme(),
    child: AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        if (_store.error != null) {
          return _Notice(
            message: AuthApi.errorMessage(_store.error!),
            retry: () => setState(() {
              _store.dispose();
              _store = TripStore(tripId: widget.tripId);
            }),
          );
        }
        if (_store.isLoading) return const _Notice();
        final trip = _store.trip;
        if (trip == null) return const _Notice(message: '삭제되었거나 찾을 수 없는 여행이에요');
        return LedgerScreen(trip: trip, store: _store, onMore: widget.onMore);
      },
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({this.message, this.retry});
  final String? message;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const ScreenTopBar(title: '여행 장부'),
          Expanded(
            child: Center(
              child: message == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message!, textAlign: TextAlign.center),
                        if (retry != null)
                          TextButton(
                            onPressed: retry,
                            child: const Text('다시 시도'),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}
