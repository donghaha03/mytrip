import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _openToss() async {
    try {
      // 공식 홈페이지 이동일 뿐, 카드 조회 동의나 연결 완료가 아니다.
      final opened = await launchUrl(
        Uri.parse('https://toss.im/'),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened) throw StateError('토스 공식 페이지를 열지 못했어요');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('페이지를 열지 못했어요. 잠시 후 다시 시도해주세요.')),
        );
      }
    }
  }

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
                      '토스뱅크 체크카드',
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
                    const SizedBox(height: 20),
                    const Text(
                      '사용내역을 자동으로 가져오려면 토스뱅크를 지원하는 조회 서비스의 API 권한이 필요해요. 현재 공개 API에서는 연결 경로를 확인하지 못했어요.',
                    ),
                    const SizedBox(height: 16),
                    const FilledButton(
                      key: ValueKey('toss-bank-connect'),
                      onPressed: null,
                      child: Text('토스뱅크 연결 · 지원 확인 필요'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('toss-official-page'),
                      onPressed: _openToss,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('토스 공식 페이지 열기'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '토스로 이동해도 mytrip과 연결되지는 않아요. 사용내역은 토스 앱에서 확인할 수 있어요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Material(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: const ExpansionTile(
                        title: Text('조회 동의 안내'),
                        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '카드 조회 동의와 본인 인증은 제공자의 공식 인증 화면에서 진행해요. 지금은 인증 경로가 준비되지 않아 동의를 받거나 금융정보를 수집하지 않아요.',
                          ),
                          SizedBox(height: 12),
                          Text(
                            '연동 전 제공자·조회 항목·조회 기간·보관 기간·동의 철회 방법을 먼저 안내해요. 장부에 사용할 카드와 여행을 선택한 뒤 연결해야 해요.',
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
