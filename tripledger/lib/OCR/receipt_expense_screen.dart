import 'package:flutter/material.dart';

import '../AppColors.dart';
import '../api/api.dart';
import 'api/ocr_api.dart';
import 'ocr_style.dart';

/// 영수증에서 읽은 내용을 확인·수정한 뒤 지출로 저장한다. 저장하면 true로 닫힌다.
///
/// 저장은 기존 `ExpenseApi.add`를 그대로 쓴다. 환율은 저장 시점 값이 지출에 함께 기록되고,
/// 통화가 여행 통화와 달라도 지출마다 자기 통화로 저장된다.
class ReceiptExpenseScreen extends StatefulWidget {
  const ReceiptExpenseScreen({
    super.key,
    required this.trip,
    required this.draft,
  });
  final Trip trip;
  final ExpenseDraft draft;

  @override
  State<ReceiptExpenseScreen> createState() => _ReceiptExpenseScreenState();
}

class _ReceiptExpenseScreenState extends State<ReceiptExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _place = TextEditingController(text: widget.draft.place);
  late final _amount = TextEditingController(
    text: widget.draft.amount == null
        ? ''
        : localAmt(widget.draft.amount!).replaceAll(',', ''),
  );
  late String _category = widget.draft.category;
  late String _currency = widget.draft.currency;
  late DateTime _date = widget.draft.date;
  String _paymentMethod = 'cash';
  bool _busy = false;

  @override
  void dispose() {
    _place.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? _parse(String? text) {
    final amount = double.tryParse((text ?? '').trim().replaceAll(',', ''));
    return amount == null || amount <= 0 ? null : amount;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (day == null || !mounted) return;
    // 시각은 그대로 두고 날짜만 바꾼다.
    setState(
      () => _date = DateTime(
        day.year,
        day.month,
        day.day,
        _date.hour,
        _date.minute,
      ),
    );
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ExpenseApi.add(
        widget.trip.id,
        category: _category,
        place: _place.text.trim(),
        amount: _parse(_amount.text)!,
        currency: _currency,
        paymentMethod: _paymentMethod,
        date: _date,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showOcrMessage(context, AuthApi.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ocrAppBar('영수증 내용 확인'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              if (widget.draft.notes.isNotEmpty)
                OcrCard(
                  children: [
                    for (final note in widget.draft.notes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '확인: $note',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              OcrCard(
                children: [
                  Text(
                    '${widget.trip.name}에 추가돼요. 틀린 곳은 고쳐주세요.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 17),
                  const _Label('카테고리'),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('expense-category'),
                    initialValue: _category,
                    decoration: ocrInput(),
                    items: [
                      for (final category in categoryIcons.keys)
                        DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(
                                iconOfCategory(category),
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 11),
                              Text(category),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) => _category = value ?? _category,
                  ),
                  const SizedBox(height: 17),
                  const _Label('결제수단'),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('expense-payment'),
                    initialValue: _paymentMethod,
                    decoration: ocrInput(),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('현금')),
                      DropdownMenuItem(value: 'card', child: Text('카드')),
                    ],
                    onChanged: (value) =>
                        _paymentMethod = value ?? _paymentMethod,
                  ),
                  const SizedBox(height: 17),
                  const _Label('장소 / 사용처'),
                  TextFormField(
                    key: const ValueKey('expense-place'),
                    controller: _place,
                    maxLength: 50,
                    decoration: ocrInput(hint: '예: 편의점, 식당, 지하철'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? '사용처를 입력해 주세요.' : null,
                  ),
                  const SizedBox(height: 13),
                  const _Label('금액'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          key: const ValueKey('expense-amount'),
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: ocrInput(hint: '예: 1500'),
                          validator: (value) =>
                              _parse(value) == null ? '올바른 금액을 입력해 주세요.' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          key: const ValueKey('expense-currency'),
                          initialValue: _currency,
                          decoration: ocrInput(),
                          items: [
                            for (final currency in {
                              widget.trip.currency,
                              'KRW',
                              ...currencies,
                            })
                              DropdownMenuItem(
                                value: currency,
                                child: Text(currency),
                              ),
                          ],
                          onChanged: (value) => _currency = value ?? _currency,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  const _Label('날짜'),
                  InkWell(
                    onTap: _busy ? null : _pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: ocrInput(),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 11),
                          Text(dayOnly(_date)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('expense-save'),
                onPressed: _busy ? null : _save,
                style: ocrPrimaryButton,
                child: _busy ? ocrButtonSpinner : const Text('지출 저장하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
