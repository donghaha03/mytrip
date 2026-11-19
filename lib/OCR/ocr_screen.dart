import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../api/api.dart' show ApiException, AuthApi;
import 'consent_screen.dart';
import 'receipt_result.dart';
import 'receipt_service.dart';

/// 사진을 고르거나 찍어 영수증을 인식하고 결과를 보여준다. 저장은 하지 않는다.
class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key, this.service, this.pickImage});

  /// 테스트에서 가짜 서버·가짜 사진 선택을 끼울 때만 넘긴다.
  final OcrService? service;
  final Future<Uint8List?> Function(ImageSource source)? pickImage;

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  late final OcrService _service = widget.service ?? OcrService();
  Uint8List? _photo;
  OcrReceipt? _receipt;
  bool _busy = false;
  String? _error;

  // 품목 번역: 선택한 언어(null = 원문)와 언어별로 받아 둔 결과.
  String? _language;
  final _translations = <String, List<String>>{};

  @override
  void dispose() {
    if (widget.service == null) _service.close();
    super.dispose();
  }

  Future<Uint8List?> _pickWithPlugin(ImageSource source) async {
    // 큰 사진은 줄여서 보낸다(서버 한도와 전송 시간).
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  }

  /// 작업 하나를 실행하는 동안 버튼을 막고, 실패하면 문구를 보여준다.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      await action();
    } on ApiException catch (e) {
      error = AuthApi.errorMessage(e);
    } catch (_) {
      error = '사진을 불러오지 못했어요. 카메라·사진 접근 권한을 확인해주세요.';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Future<void> _pick(ImageSource source) => _run(() async {
    final photo = await (widget.pickImage ?? _pickWithPlugin)(source);
    if (photo == null || !mounted) return; // 선택 취소
    setState(() {
      _photo = photo;
      _receipt = null;
      _language = null;
      _translations.clear();
    });
  });

  /// 동의했으면 true. 아직이면 동의 화면을 띄워 결정을 받는다.
  Future<bool> _ensureConsent({bool manage = false}) async {
    if (!manage && await _service.consent() == true) return true;
    if (!mounted) return false;
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => OcrConsentScreen(service: _service)),
    );
    return accepted == true;
  }

  Future<void> _recognize() => _run(() async {
    if (!await _ensureConsent()) return;
    final receipt = await _service.recognize(_photo!);
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
          : await _service.translate(filled, language);
      var next = 0;
      _translations[language] = [
        for (final name in names) name.isEmpty ? '' : translated[next++],
      ];
    }
    if (mounted) setState(() => _language = language);
  });

  String _money(double? value, String? currency) => value == null
      ? '확인 필요'
      : '${NumberFormat('#,##0.##').format(value)}${currency == null ? '' : ' $currency'}';

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    return Scaffold(
      appBar: AppBar(
        title: const Text('영수증 인식'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => _ensureConsent(manage: true),
            child: const Text('사진 전송 동의'),
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
                    onPressed: _busy ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('사진 촬영'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('사진 선택'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_photo == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  '영수증 사진을 촬영하거나 선택해주세요.\n카드번호·연락처 등 개인정보는 가려주세요.',
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                child: Text(
                  _busy
                      ? '처리 중…'
                      : receipt == null
                      ? '이 사진으로 인식'
                      : '다시 인식',
                ),
              ),
            ],
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
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
      const Divider(height: 32),
      Text(
        receipt.merchant ?? '상호명 확인 필요',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        '${date == null ? '날짜 확인 필요' : DateFormat('yyyy.MM.dd').format(date)}'
        ' · ${receipt.category}',
      ),
      const SizedBox(height: 12),
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
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (receipt.items.isNotEmpty) ...[
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text('품목', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
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
      if (receipt.taxes.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('세금', style: TextStyle(fontWeight: FontWeight.w700)),
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
      if (receipt.taxFree != null ||
          receipt.discount != null ||
          receipt.exemptedTax != null ||
          receipt.taxFreeBase != null ||
          receipt.adjustments.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('할인·면세·추가금', style: TextStyle(fontWeight: FontWeight.w700)),
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
          _Line('할인 합계', _money(receipt.discount, receipt.adjustmentCurrency)),
        for (final line in receipt.adjustments)
          _Line(
            '${line.isDiscount ? '할인' : '추가금'} · ${line.label}',
            _money(line.amount, line.currency),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            '총 결제금액에 이미 반영된 값이라 다시 더하거나 빼지 않아요.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ];
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.emphasized = false});
  final String label, value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: emphasized ? 18 : 14,
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
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
