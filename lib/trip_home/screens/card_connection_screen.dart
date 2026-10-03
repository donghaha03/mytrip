import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/trip_store.dart';
import '../models/trip.dart';
import '../services/backend.dart';
import '../services/card_sync_api.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_top_bar.dart';

class CardConnectionScreen extends StatefulWidget {
  const CardConnectionScreen({super.key, required this.trip});
  final Trip trip;

  @override
  State<CardConnectionScreen> createState() => _CardConnectionScreenState();
}

class _CardConnectionScreenState extends State<CardConnectionScreen> {
  bool _busy = false;
  String? _message;
  bool _failed = false;

  Future<void> _sync() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    try {
      if (!CardSyncApi.configured ||
          !Backend.isFirebase ||
          !tripStore.isRemote) {
        throw StateError('실제 연동 서버와 로그인이 필요해요');
      }
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw StateError('로그인이 필요해요');
      final result = await CardSyncApi.synchronize(
        tripId: widget.trip.id,
        idToken: token,
      );
      if (mounted) {
        setState(
          () => _message =
              '${result.received}건을 확인했어요. ${result.skipped > 0 ? '${result.skipped}건은 확인이 필요해 자동 등록을 보류했어요.' : '새 내역은 장부에 자동 반영돼요.'}',
        );
      }
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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: tripStore,
    builder: (context, _) {
      final canSync =
          CardSyncApi.configured && Backend.isFirebase && tripStore.isRemote;
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenTopBar(title: '카드 연동'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    const Icon(
                      Icons.credit_card_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '실제 카드 연결',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canSync ? '인증된 서버 연결을 확인해주세요' : '실제 카드 미연결',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '토스뱅크 체크카드',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '현재 앱에서는 토스뱅크 결제내역을 받을 수 없어요. 카드 정보를 입력하는 것만으로 연결되지는 않아요.',
                    ),
                    const SizedBox(height: 20),
                    Material(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: const ExpansionTile(
                        title: Text('연결에 필요한 준비'),
                        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '1. 토스뱅크 조회를 지원하는 서비스의 운영 권한\n2. 로그인과 사용자별 인증을 처리하는 보안 서버\n3. 제공자 공식 화면에서 본인 인증과 조회 동의',
                          ),
                          SizedBox(height: 12),
                          Text(
                            '계좌 입출금 조회와 카드 승인내역은 달라요. 토스뱅크는 오픈뱅킹 참여 은행이지만, 카드 가맹점·취소 정보와 결제 즉시 반영을 별도로 확인해야 해요.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            '연결 전 조회 항목·기간·보관 기간·동의 철회 방법을 안내해야 해요. 현재는 금융정보를 수집하지 않아요.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (canSync)
                      FilledButton(
                        onPressed: _busy ? null : _sync,
                        child: const Text('연결된 카드 내역 확인'),
                      ),
                    const Text(
                      '전체 카드번호·CVC·비밀번호는 이 화면에서 받지 않아요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
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
