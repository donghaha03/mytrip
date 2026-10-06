import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../widgets/screen_top_bar.dart';

const receiptConsentVersion = 'gemini-free-v1';
const receiptServerOrigin = String.fromEnvironment(
  'RECEIPT_SERVER_URL',
  defaultValue: 'https://mytrip-receipt.mytrip-local-receipt.workers.dev',
);

// Consent is scoped to this provider, policy version and destination, not a key.
String receiptConsentKey(Uri url) =>
    'receipt_consent:$receiptConsentVersion:${url.origin}';

Future<bool?> receiptConsent(Uri url) async =>
    (await SharedPreferences.getInstance()).getBool(receiptConsentKey(url));

class ReceiptConsentScreen extends StatefulWidget {
  const ReceiptConsentScreen({
    super.key,
    required this.url,
    required this.onDecision,
  });
  final Uri url;
  final ValueChanged<bool> onDecision;

  @override
  State<ReceiptConsentScreen> createState() => _ReceiptConsentScreenState();
}

class _ReceiptConsentScreenState extends State<ReceiptConsentScreen> {
  bool _adult = false, _busy = false;
  String? _error;

  Future<void> _decide(bool accepted) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await (await SharedPreferences.getInstance()).setBool(
        receiptConsentKey(widget.url),
        accepted,
      );
      if (!saved) throw const FormatException();
      if (mounted) widget.onDecision(accepted);
    } catch (_) {
      if (mounted) setState(() => _error = '동의를 저장하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const ScreenTopBar(title: '영수증 인식 안내'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
                const SizedBox(height: 24),
                const Text(
                  '한 번 동의하면, 다음부터 바로 인식해요',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const Text(
                  '확인한 영수증 사진을 Cloudflare를 통해 Google Gemini로 보내 상호명·금액·품목을 읽어요. 결과는 직접 확인하고 저장해요.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gemini 무료 서비스는 사진과 결과를 제품 개선에 사용하거나 사람이 검토할 수 있어요. 카드번호·연락처 등 개인정보를 가린 사진만 사용해주세요.',
                ),
                const SizedBox(height: 12),
                const Text(
                  '동의하지 않아도 직접 지출을 입력할 수 있어요. 촬영 화면의 ‘사진 전송 동의’에서 언제든 철회할 수 있어요.',
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('전송·보관·무료 사용 안내'),
                  children: [
                    Text(
                      '중계 서버: ${widget.url.origin}\n중계 서버는 사진·인식 결과를 저장하거나 기록하지 않아요. 악용 방지를 위한 날짜별 익명 접속 해시와 사용량만 저장하며, Cloudflare 복구 기록에 최대 30일 남을 수 있어요. Google의 보관·사용 조건은 아래 정책을 확인해주세요.\n무료 한도 내에서 사용하며 한도 초과 시 중단해요. 자동 유료 전환은 없어요. 유럽 경제 지역·스위스·영국에서는 이 무료 인식을 제공하지 않아요.',
                    ),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse('https://ai.google.dev/gemini-api/terms'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text('Google 데이터 처리·보관 정책'),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _adult,
                  title: const Text('만 18세 이상이며, 위 사진 전송·처리에 동의해요'),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _adult = value ?? false),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _adult && !_busy ? () => _decide(true) : null,
                  child: const Text('동의하고 시작하기'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _decide(false),
                  child: const Text('동의하지 않고 직접 입력하기'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
