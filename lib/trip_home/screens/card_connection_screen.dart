import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/trip_store.dart';
import '../models/trip.dart';
import '../services/backend.dart';
import '../services/card_sync_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_top_bar.dart';

class CardConnectionScreen extends StatefulWidget {
  const CardConnectionScreen({super.key, required this.trip});
  final Trip trip;
  @override
  State<CardConnectionScreen> createState() => _CardConnectionScreenState();
}

class _CardConnectionScreenState extends State<CardConnectionScreen> {
  bool _busy = false;
  bool _demoLinked = false;
  String? _message;
  bool _failed = false;
  Trip get trip => widget.trip;
  Expense? get _latestDemo => trip.expensesNewestFirst
      .where((e) => e.source == 'demo-card')
      .firstOrNull;

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    try {
      final message = await action();
      if (mounted) setState(() => _message = message);
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = e is StateError
              ? e.message.toString()
              : '연결하지 못했어요. 기록은 그대로 유지돼요.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _demo(
    ExpenseStatus status, {
    bool repeat = false,
    bool newPayment = false,
  }) => _run(() async {
    final old = newPayment ? null : _latestDemo;
    final event = repeat && old != null
        ? old
        : Expense(
            id: old?.id ?? 'demo_card_${DateTime.now().microsecondsSinceEpoch}',
            icon: '💳',
            place: '테스트 카드 결제',
            amount: status == ExpenseStatus.cancelled
                ? 0
                : status == ExpenseStatus.partiallyCancelled
                ? 500
                : 1000,
            originalAmount: 1000,
            date: old?.date ?? DateTime.now(),
            currency: old?.currency ?? trip.country.currency,
            paymentMethod: PaymentMethod.card,
            source: 'demo-card',
            status: status,
          );
    await tripStore.applyDemoCardEvent(trip.id, event);
    return repeat
        ? '같은 이벤트를 재수신했어요. 중복 기록 없이 같은 내역을 갱신했어요.'
        : '테스트 ${status.label}이 장부에 바로 반영됐어요. 실제 결제는 발생하지 않아요.';
  });

  Future<void> _sync() => _run(() async {
    if (!Backend.isFirebase || !tripStore.isRemote) {
      throw StateError('실제 연동은 로그인된 Firebase 모드에서 가능해요');
    }
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (token == null) throw StateError('로그인이 필요해요');
    final result = await CardSyncApi.synchronize(
      tripId: trip.id,
      idToken: token,
    );
    return '${result.received}건을 확인했어요. ${result.skipped > 0 ? '${result.skipped}건은 통화·취소 정보를 확인해야 해 자동 등록을 보류했어요.' : '새 내역은 장부에 자동 반영돼요.'}';
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: tripStore,
    builder: (context, _) {
      final demo = _latestDemo;
      final local = !tripStore.isRemote;
      final linked = _demoLinked || demo != null;
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const ScreenTopBar(title: '카드 연동'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.credit_card_rounded,
                            size: 36,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            local ? '테스트 카드' : '카드 자동 기록',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            local
                                ? '실제 카드와 연결되지 않은 테스트예요. 승인·중복 수신·취소가 장부에 반영되는 흐름을 확인할 수 있어요.'
                                : '카드사 승인내역을 서버에서 조회하고, 새 내역을 받으면 장부가 자동 갱신돼요.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (local) ...[
                      Text(
                        linked ? '테스트 모드 사용 중' : '테스트 카드 미연결',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      if (!linked)
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _demoLinked = true),
                          child: const Text('테스트 카드 연결'),
                        ),
                      if (linked) ...[
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _demo(
                                  ExpenseStatus.approved,
                                  newPayment: true,
                                ),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(
                            '테스트 승인 · 1,000 ${trip.country.currency}',
                          ),
                        ),
                        if (demo != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            '최근 테스트: ${demo.status.label} · 남은 결제액 ${formatNumber(demo.amount.truncate())} ${demo.currencyOf(trip)}',
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _demo(demo.status, repeat: true),
                            child: const Text('동일 이벤트 재수신'),
                          ),
                          if (demo.status == ExpenseStatus.approved)
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () =>
                                        _demo(ExpenseStatus.partiallyCancelled),
                              child: const Text('테스트 부분 취소 · 500'),
                            ),
                          if (demo.status.countsAsSpending)
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _demo(ExpenseStatus.cancelled),
                              child: const Text('테스트 전체 취소'),
                            ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        '테스트 내역은 임시 저장되며 새로고침하면 초기화돼요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const Divider(height: 40),
                    const Text(
                      '실제 카드 연결',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '제공자 이용 신청과 본인 인증·동의, 로그인된 사용자 전용 서버가 필요해요. 카드번호나 비밀번호를 이 테스트 화면에 입력하지 마세요.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '결제 즉시 수신은 카드사·제공자 지원에 따라 달라요. 조회 제한과 반영 지연이 있으며, 면세 여부는 직접 확인해야 해요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!CardSyncApi.configured)
                      const Text(
                        '실제 연동 서버 미설정',
                        style: TextStyle(color: AppColors.textSecondary),
                      )
                    else if (!local)
                      FilledButton(
                        onPressed: _busy ? null : _sync,
                        child: const Text('연결된 카드 내역 확인'),
                      ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator(),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _failed
                                ? AppColors.danger
                                : AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
