import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/trip_store.dart';
import '../models/test_card.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_top_bar.dart';

class CardRegistrationScreen extends StatefulWidget {
  const CardRegistrationScreen({super.key, required this.trip});
  final Trip trip;

  @override
  State<CardRegistrationScreen> createState() => _CardRegistrationScreenState();
}

class _CardRegistrationScreenState extends State<CardRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nickname;
  late final TextEditingController _lastFour;
  late String _issuer;
  late String _kind;
  bool _testAccepted = false;
  bool _storageAccepted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final card = tripStore.testCardFor(widget.trip.id);
    _issuer = card?.issuer ?? '토스뱅크';
    _kind = card?.kind ?? '체크카드';
    _nickname = TextEditingController(text: card?.nickname ?? '여행 카드');
    _lastFour = TextEditingController(text: card?.lastFour ?? '');
  }

  @override
  void dispose() {
    _nickname.dispose();
    _lastFour.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (!_testAccepted || !_storageAccepted) {
      setState(() => _error = '개발용 안내 두 항목을 확인해주세요');
      return;
    }
    try {
      tripStore.registerTestCard(
        widget.trip.id,
        TestCard(
          issuer: _issuer,
          kind: _kind,
          nickname: _nickname.text.trim(),
          lastFour: _lastFour.text,
        ),
        noticeAccepted: _testAccepted && _storageAccepted,
      );
      Navigator.of(context).pop();
    } on StateError catch (e) {
      setState(() => _error = e.message.toString());
    } on ArgumentError {
      setState(() => _error = '입력 정보를 확인해주세요');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const ScreenTopBar(title: '카드 정보 입력'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '임시 등록 · 실제 카드 미연결',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _issuer,
                      decoration: const InputDecoration(labelText: '카드사 / 은행'),
                      menuMaxHeight: 320,
                      items: TestCard.issuers
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _issuer = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _kind,
                      decoration: const InputDecoration(labelText: '카드 종류'),
                      items: TestCard.kinds
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _kind = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('card-nickname'),
                      controller: _nickname,
                      decoration: const InputDecoration(
                        labelText: '카드 별칭',
                        helperText: '카드번호·이름·전화번호 대신 별칭을 사용하세요',
                      ),
                      maxLength: 30,
                      validator: (v) => TestCard.nicknameError(v ?? ''),
                      enableSuggestions: false,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('card-last-four'),
                      controller: _lastFour,
                      decoration: const InputDecoration(
                        labelText: '끝 4자리 (선택)',
                        helperText: '비워두어도 등록할 수 있어요',
                      ),
                      keyboardType: TextInputType.number,
                      // 전체 번호 붙여넣기는 자르지 않고 거부한다.
                      inputFormatters: [
                        TextInputFormatter.withFunction(
                          (old, next) =>
                              RegExp(r'^\d{0,4}$').hasMatch(next.text)
                              ? next
                              : old,
                        ),
                      ],
                      validator: (v) => TestCard.lastFourError(v ?? ''),
                      enableSuggestions: false,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '개발용 임시 등록 안내',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '화면과 장부 반영 흐름을 테스트하기 위해 카드사·종류·별칭·선택한 끝 4자리만 사용해요. 서버에 전송하지 않고 현재 앱 메모리에만 보관해요. 새로고침·로그아웃·등록 해제 시 지워져요.',
                          ),
                          SizedBox(height: 8),
                          Text(
                            '전체 카드번호, CVC, 비밀번호, 인증번호는 입력하지 마세요. 실제 결제내역 조회 동의서가 아니며, 실연동 시 제공자의 공식 동의·본인 인증이 따로 필요해요.',
                          ),
                        ],
                      ),
                    ),
                    CheckboxListTile(
                      key: const ValueKey('card-test-notice'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _testAccepted,
                      onChanged: (v) =>
                          setState(() => _testAccepted = v ?? false),
                      title: const Text('실제 연결·결제가 아닌 테스트임을 확인했어요'),
                    ),
                    CheckboxListTile(
                      key: const ValueKey('card-storage-notice'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _storageAccepted,
                      onChanged: (v) =>
                          setState(() => _storageAccepted = v ?? false),
                      title: const Text('입력 항목과 임시 보관·삭제 안내를 확인했어요'),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    FilledButton(onPressed: _save, child: const Text('임시 등록')),
                    const SizedBox(height: 12),
                    const Text(
                      '다른 카드사도 임시 등록할 수 있지만, 실제 조회 지원은 카드사·상품·인증 방식에 따라 달라요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
