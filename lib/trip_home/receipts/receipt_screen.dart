import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/screen_top_bar.dart';
import '../models/country.dart';
import '../models/trip.dart';
import 'receipt_draft.dart';
import 'receipt_platform.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  @override
  void dispose() {
    closeReceiptCamera();
    super.dispose();
  }

  Future<void> _capture() async {
    try {
      final raw = await openReceiptCamera();
      if (!mounted) return;
      if (raw == null) {
        Navigator.of(context).pop();
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final draft = ReceiptDraft.parse(
        data['text'] as String,
        confidence: (data['confidence'] as num).toDouble(),
      );
      final result = await Navigator.of(context).push<ReceiptDraft>(
        MaterialPageRoute(
          builder: (_) => ReceiptReviewScreen(
            draft: draft,
            image: base64Decode((data['image'] as String).split(',').last),
            text: data['text'] as String,
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              '이 환경에서는 영수증 인식을 시작하지 못했어요. HTTPS 웹 주소·최신 브라우저에서 다시 시도하거나 수동으로 입력해주세요.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const ScreenTopBar(title: '영수증 촬영'),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _error == null
                    ? const Text('영수증 촬영 화면을 열고 있어요…')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _capture,
                            child: const Text('다시 시도'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('수동 입력으로 돌아가기'),
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

class ReceiptReviewScreen extends StatefulWidget {
  const ReceiptReviewScreen({
    super.key,
    required this.draft,
    required this.image,
    required this.text,
  });
  final ReceiptDraft draft;
  final Uint8List image;
  final String text;
  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  final _form = GlobalKey<FormState>();
  late final _merchant = TextEditingController(text: widget.draft.merchant);
  late final _amount = TextEditingController(
    text: widget.draft.amount?.truncate().toString() ?? '',
  );
  late final _date = TextEditingController(
    text: widget.draft.date?.toIso8601String().substring(0, 10) ?? '',
  );
  late String? _currency = widget.draft.currency;
  late String _category = widget.draft.category;
  bool _confirmed = false;
  DateTime? get _parsedDate {
    final input = _date.text.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(input)) return null;
    final parsed = DateTime.tryParse(input);
    return parsed?.toIso8601String().substring(0, 10) == input ? parsed : null;
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    _date.dispose();
    super.dispose();
  }

  void _apply() {
    if (!_confirmed || !_form.currentState!.validate()) return;
    Navigator.of(context).pop(
      ReceiptDraft(
        merchant: _merchant.text.trim(),
        date: _parsedDate,
        amount: double.parse(_amount.text),
        currency: _currency,
        category: _category,
        warnings: [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const ScreenTopBar(title: '영수증 내용 확인'),
          Expanded(
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Image.memory(
                    widget.image,
                    height: 280,
                    fit: BoxFit.contain,
                    semanticLabel: '인식한 영수증 원본',
                  ),
                  const SizedBox(height: 16),
                  const Text('자동으로 저장하지 않아요. 원본과 비교해 수정한 뒤 지출 양식에 적용해주세요.'),
                  for (final warning in widget.draft.warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        warning,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _merchant,
                    maxLength: 50,
                    decoration: const InputDecoration(labelText: '상호명'),
                    validator: (value) =>
                        value?.trim().isNotEmpty == true ? null : '상호명을 확인해주세요',
                  ),
                  TextFormField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '최종 결제금액 (정수)',
                    ),
                    validator: (s) =>
                        RegExp(r'^\d+$').hasMatch(s ?? '') &&
                            (double.tryParse(s ?? '') ?? 0) > 0 &&
                            double.parse(s!).isFinite
                        ? null
                        : '최종 결제금액을 1 이상 정수로 확인해주세요',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    isExpanded: true,
                    menuMaxHeight: 300,
                    decoration: const InputDecoration(
                      labelText: '결제 통화 (확인 필요)',
                    ),
                    items: [
                      for (final c in kExpenseCurrencies.where(
                        (c) => c.currency != 'XXX',
                      ))
                        DropdownMenuItem(
                          value: c.currency,
                          child: Text('${c.currency} · ${c.unitLabel}'),
                        ),
                    ],
                    onChanged: (code) => setState(() => _currency = code),
                    validator: (s) => s == null ? '통화를 직접 확인해주세요' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _date,
                    decoration: const InputDecoration(
                      labelText: '결제일 (YYYY-MM-DD)',
                    ),
                    validator: (_) =>
                        _parsedDate == null ? '올바른 결제일을 확인해주세요' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('카테고리 추천 · 변경할 수 있어요'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final category in expenseCategoryIcons.keys)
                        ChoiceChip(
                          label: Text(category),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                    ],
                  ),
                  ExpansionTile(
                    title: const Text('인식한 원문 보기'),
                    children: [SelectableText(widget.text)],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _confirmed,
                    title: const Text('상호명·날짜·최종 금액·통화를 원본과 비교했어요'),
                    onChanged: (value) =>
                        setState(() => _confirmed = value ?? false),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _confirmed ? _apply : null,
                child: const Text('확인 후 지출 양식에 적용'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
