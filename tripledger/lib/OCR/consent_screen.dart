import 'package:flutter/material.dart';

import '../AppColors.dart';
import '../api/api.dart';
import 'api/ocr_api.dart';
import 'ocr_style.dart';

const ocrTermsUrl = 'https://www.anthropic.com/legal/commercial-terms';

/// 영수증 사진을 외부 서비스로 보내기 전에 한 번 받는 동의.
/// 동의하면 true, 거절하면 false로 닫힌다.
class OcrConsentScreen extends StatefulWidget {
  const OcrConsentScreen({super.key});

  @override
  State<OcrConsentScreen> createState() => _OcrConsentScreenState();
}

class _OcrConsentScreenState extends State<OcrConsentScreen> {
  bool _adult = false, _busy = false;

  Future<void> _decide(bool accepted) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await OcrApi.setConsent(accepted);
      if (mounted) Navigator.of(context).pop(accepted);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showOcrMessage(context, AuthApi.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14,
      height: 1.5,
    );
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ocrAppBar('영수증 인식 안내'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            OcrCard(
              children: [
                const Text(
                  '한 번 동의하면, 다음부터 바로 인식해요',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '확인한 영수증 사진을 Cloudflare 중계 서버를 통해 Anthropic의 Claude로 보내 '
                  '상호명·금액·품목·세금을 읽어요. 번역 버튼을 누르면 품목명만 같은 서비스로 보내요.',
                  style: body,
                ),
                const SizedBox(height: 12),
                const Text(
                  '카드번호·연락처 등 개인정보를 가린 사진만 사용해주세요. Anthropic이 받은 내용을 '
                  '어떻게 처리·보관하는지는 아래 약관에서 확인할 수 있어요.',
                  style: body,
                ),
                const SizedBox(height: 12),
                const Text(
                  '동의하지 않으면 사진을 보내지 않아요. 인식 화면에서 언제든 철회할 수 있어요.',
                  style: body,
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  shape: const Border(),
                  title: const Text(
                    '전송·보관·이용 한도 안내',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  children: [
                    Text(
                      '중계 서버: ${OcrApi.serverOrigin}\n'
                      '중계 서버는 사진·품목명·결과를 저장하거나 기록하지 않아요. 악용 방지를 위한 '
                      '날짜별 익명 접속 해시와 사용량만 저장하며, Cloudflare 복구 기록에 최대 30일 '
                      '남을 수 있어요.\n'
                      '인식 비용은 서버 운영자가 부담하고 사용자에게 청구되지 않아요. 전체 사용자 합계 '
                      '하루 200건 한도에 도달하면 그날은 인식을 중단해요.',
                      style: body.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text('Anthropic 상용 약관', style: body.copyWith(fontSize: 13)),
                    const SelectableText(
                      ocrTermsUrl,
                      style: TextStyle(color: AppColors.primary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              value: _adult,
              title: const Text(
                '만 18세 이상이며, 위 영수증 전송·처리에 동의해요',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _adult = value ?? false),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _adult && !_busy ? () => _decide(true) : null,
              style: ocrPrimaryButton,
              child: _busy ? ocrButtonSpinner : const Text('동의하고 시작하기'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _decide(false),
              child: const Text(
                '동의하지 않기',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
