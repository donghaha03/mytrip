import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../AppColors.dart';
import '../api/api.dart';
import 'api/ocr_api.dart';
import 'camera_screen.dart';
import 'consent_screen.dart';
import 'ocr_style.dart';
import 'receipt_expense_screen.dart';

/// 장부의 "영수증 OCR" 버튼이 부른다. 영수증으로 지출을 추가하는 흐름
/// (사진 → 동의 → 인식 → 내용 확인 → 저장)을 열고, 저장되면 안내 문구를 띄운다.
Future<void> openReceiptOcr(BuildContext context, Trip trip) async {
  final saved = await Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => OcrScreen(trip: trip)));
  if (saved == true && context.mounted) {
    showOcrMessage(context, '지출이 추가되었습니다.');
  }
}

/// 사진을 고르거나 찍어 영수증을 인식하고 결과를 보여준다.
///
/// [trip]을 넘기면 결과 아래에 "이 내용으로 지출 추가" 버튼이 생기고, 저장하면 true로
/// 닫힌다. 넘기지 않으면(단독 실행) 결과만 보여주고 저장하지 않는다.
class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key, this.trip});
  final Trip? trip;

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  Uint8List? _photo;
  OcrReceipt? _receipt;
  bool _busy = false;

  // 품목 번역: 선택한 언어(null = 원문)와 언어별로 받아 둔 결과.
  String? _language;
  final _translations = <String, List<String>>{};

  /// 작업 하나를 실행하는 동안 버튼을 막고, 실패하면 문구를 보여준다.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showOcrMessage(context, AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setPhoto(Uint8List photo) => setState(() {
    _photo = photo;
    _receipt = null;
    _language = null;
    _translations.clear();
  });

  Future<void> _pick() => _run(() async {
    final photo = await OcrApi.pickPhoto(camera: false);
    if (photo == null || !mounted) return; // 선택 취소
    _setPhoto(photo);
  });

  /// 앱 안 촬영 화면을 연다. 거기서 "이 사진으로 인식"을 눌렀으면 바로 인식한다.
  Future<void> _shoot() async {
    final photo = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const OcrCameraScreen()),
    );
    if (photo == null || !mounted) return; // 찍지 않고 돌아옴
    _setPhoto(photo);
    await _recognize();
  }

  /// 동의했으면 true. 아직이면 동의 화면을 띄워 결정을 받는다.
  Future<bool> _ensureConsent({bool manage = false}) async {
    if (!manage && await OcrApi.consent() == true) return true;
    if (!mounted) return false;
    final accepted = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const OcrConsentScreen()));
    return accepted == true;
  }

  Future<void> _recognize() => _run(() async {
    if (!await _ensureConsent()) return;
    final receipt = await OcrApi.recognize(_photo!);
    if (!mounted) return;
    setState(() => _receipt = receipt);
  });

  Future<void> _translate(String? language) => _run(() async {
    final names = [for (final item in _receipt!.items) item.name ?? ''];
    if (language != null && !_translations.containsKey(language)) {
      if (!await _ensureConsent()) return;
      // 이름이 비어 있는 줄은 빼고 보낸 뒤 제자리에 되돌린다.
      final filled = [
        for (final name in names)
          if (name.isNotEmpty) name,
      ];
      final translated = filled.isEmpty
          ? <String>[]
          : await OcrApi.translate(filled, language);
      var next = 0;
      _translations[language] = [
        for (final name in names) name.isEmpty ? '' : translated[next++],
      ];
    }
    if (mounted) setState(() => _language = language);
  });

  /// 인식 결과를 지출 입력 화면으로 넘기고, 저장됐으면 이 화면도 닫는다.
  Future<void> _addExpense(Trip trip, OcrReceipt receipt) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReceiptExpenseScreen(
          trip: trip,
          draft: ExpenseDraft.fromReceipt(receipt, tripCurrency: trip.currency),
        ),
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  String _money(double? value, String? currency) => value == null
      ? '확인 필요'
      : '${localAmt(value)}${currency == null ? '' : ' $currency'}';

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    final trip = widget.trip;
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: trip == null || receipt == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                key: const ValueKey('ocr-add-expense'),
                onPressed: _busy ? null : () => _addExpense(trip, receipt),
                style: ocrPrimaryButton,
                child: const Text('이 내용으로 지출 추가'),
              ),
            ),
      appBar: ocrAppBar(
        '영수증 인식',
        actions: [
          TextButton(
            onPressed: _busy ? null : () => _ensureConsent(manage: true),
            child: const Text('전송 동의'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _shoot,
                    style: ocrOutlinedButton,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('사진 촬영'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pick,
                    style: ocrOutlinedButton,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('사진 선택'),
                  ),
                ),
              ],
            ),
            if (_photo == null)
              const OcrCard(
                children: [
                  SizedBox(height: 24),
                  Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.textTertiary,
                    size: 44,
                  ),
                  SizedBox(height: 12),
                  Text(
                    '영수증 사진을 촬영하거나 선택해주세요.\n카드번호·연락처 등 개인정보는 가려주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              )
            else ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(
                  _photo!,
                  height: 240,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 80,
                    child: Center(child: Text('미리보기를 표시할 수 없는 사진이에요')),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('ocr-recognize'),
                onPressed: _busy ? null : _recognize,
                style: ocrPrimaryButton,
                child: _busy
                    ? ocrButtonSpinner
                    : Text(receipt == null ? '이 사진으로 인식' : '다시 인식'),
              ),
            ],
            if (receipt != null) ..._result(receipt),
          ],
        ),
      ),
    );
  }

  List<Widget> _result(OcrReceipt receipt) {
    final names = _language == null ? null : _translations[_language];
    final date = receipt.date;
    return [
      OcrCard(
        children: [
          Text(
            receipt.merchant ?? '상호명 확인 필요',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                iconOfCategory(receipt.category),
                color: AppColors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '${date == null ? '날짜 확인 필요' : dayOnly(date)}'
                ' · ${receipt.category}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Divider(height: 25, color: AppColors.divider),
          _Line(
            '총 결제금액',
            _money(receipt.amount, receipt.currency),
            emphasized: true,
          ),
          for (final warning in receipt.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '확인: $warning',
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),
        ],
      ),
      if (receipt.items.isNotEmpty)
        OcrCard(
          children: [
            Row(
              children: [
                const Expanded(child: _Title('품목')),
                for (final (label, language) in [
                  ('원문', null),
                  ('한국어', 'ko'),
                  ('English', 'en'),
                ])
                  TextButton(
                    onPressed: _busy || _language == language
                        ? null
                        : () => _translate(language),
                    child: Text(label),
                  ),
              ],
            ),
            for (final (index, item) in receipt.items.indexed)
              _Line(
                '${names?[index].isNotEmpty == true ? names![index] : item.name ?? '이름 확인 필요'}'
                '${item.quantity == null ? '' : ' × ${item.quantity}'}',
                _money(item.amount, receipt.currency),
              ),
          ],
        ),
      if (receipt.taxes.isNotEmpty)
        OcrCard(
          children: [
            const _Title('세금'),
            for (final tax in receipt.taxes)
              _Line(
                '${tax.label}${switch (tax.included) {
                  true => ' (결제금액에 포함)',
                  false => ' (결제금액에 미포함)',
                  null => ' (포함 여부 확인 필요)',
                }}',
                _money(tax.amount, tax.currency ?? receipt.currency),
              ),
          ],
        ),
      if (receipt.taxFree != null ||
          receipt.discount != null ||
          receipt.exemptedTax != null ||
          receipt.taxFreeBase != null ||
          receipt.adjustments.isNotEmpty)
        OcrCard(
          children: [
            const _Title('할인·면세·추가금'),
            if (receipt.taxFree != null)
              _Line('면세', receipt.taxFree! ? '적용됨' : '적용 안 됨'),
            if (receipt.exemptedTax != null)
              _Line(
                '면세로 빠진 세금',
                _money(receipt.exemptedTax, receipt.adjustmentCurrency),
              ),
            if (receipt.taxFreeBase != null)
              _Line(
                '면세 대상 금액',
                _money(receipt.taxFreeBase, receipt.adjustmentCurrency),
              ),
            if (receipt.discount != null)
              _Line(
                '할인 합계',
                _money(receipt.discount, receipt.adjustmentCurrency),
              ),
            for (final line in receipt.adjustments)
              _Line(
                '${line.isDiscount ? '할인' : '추가금'} · ${line.label}',
                _money(line.amount, line.currency),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '총 결제금액에 이미 반영된 값이라 다시 더하거나 빼지 않아요.',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
          ],
        ),
    ];
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.emphasized = false});
  final String label, value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: AppColors.textPrimary,
      fontSize: emphasized ? 18 : 13,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }
}
