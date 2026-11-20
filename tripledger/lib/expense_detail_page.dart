import 'package:flutter/material.dart';

import 'api/api.dart';

class ExpenseDetailPage extends StatefulWidget {
  const ExpenseDetailPage({
    super.key,
    required this.tripId,
    required this.expense,
  });

  final String tripId;
  final Expense expense;

  @override
  State<ExpenseDetailPage> createState() => _ExpenseDetailPageState();
}

class _ExpenseDetailPageState extends State<ExpenseDetailPage> {
  static const Color primary = Color(0xFF3478EF);
  static const Color background = Color(0xFFF5F7FB);
  static const Color muted = Color(0xFF8791A3);

  late Expense _expense;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _expense = widget.expense;
  }

  String _dateText(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${date.year}.${two(date.month)}.${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _editExpense() async {
    final updated = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ExpenseEditSheet(expense: _expense),
    );

    if (updated == null || !mounted) return;

    setState(() => _busy = true);

    try {
      await ExpenseApi.update(widget.tripId, updated);

      if (!mounted) return;

      setState(() {
        _expense = updated;
        _busy = false;
      });

      _showMessage('지출 기록이 수정되었습니다.');
    } catch (e) {
      if (!mounted) return;

      setState(() => _busy = false);
      _showMessage(AuthApi.errorMessage(e));
    }
  }

  Future<void> _deleteExpense() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFE05252),
                    size: 27,
                  ),
                ),
                const SizedBox(height: 17),
                const Text(
                  '지출 기록을 삭제할까요?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF20242D),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '${_expense.place}\n'
                  '${localAmt(_expense.amount)} ${_expense.currency}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF8791A3),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF596579),
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Color(0xFFE5E9F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE05252),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          '삭제하기',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      await ExpenseApi.delete(widget.tripId, _expense.id);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _busy = false);
      _showMessage(AuthApi.errorMessage(e));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final expense = _expense;
    final payment = expense.paymentMethod == 'card' ? '카드' : '현금';

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: background,
        elevation: 0,
        title: const Text(
          '지출 상세',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF20242D),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _busy ? null : _deleteExpense,
            icon: const Icon(Icons.delete_outline_rounded),
            color: Colors.red,
            tooltip: '지출 삭제',
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(17, 10, 17, 100),
            children: [
              // 지출 요약 카드
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: const Color(0xFFE5E9F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF0FF),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        iconOfCategory(expense.category),
                        color: primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 17),
                    Text(
                      expense.place,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF20242D),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${expense.category} · $payment',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      '${localAmt(expense.amount)} ${expense.currency}',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF20242D),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '결제 당시 환산 ${won(expense.amountKrw)}',
                      style: const TextStyle(
                        color: primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // 지출 정보
              _DetailRow(label: '날짜 · 시각', value: _dateText(expense.date)),
              _DetailRow(label: '카테고리', value: expense.category),
              _DetailRow(label: '결제수단', value: payment),
              _DetailRow(label: '사용처', value: expense.place),
              _DetailRow(
                label: '결제 금액',
                value: '${localAmt(expense.amount)} ${expense.currency}',
              ),

              const SizedBox(height: 15),
              const Divider(color: Color(0xFFDDE2EA)),
              const SizedBox(height: 13),

              const Text(
                '결제 당시 환율',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF20242D),
                ),
              ),
              const SizedBox(height: 17),

              _DetailRow(
                label: '기록 당시 환율',
                value:
                    '1 ${expense.currency} = ₩${expense.rate.toStringAsFixed(3)}',
              ),
              _DetailRow(label: '원화 환산 금액', value: won(expense.amountKrw)),

              const SizedBox(height: 10),
              const Text(
                '기록 당시 저장된 환율을 기준으로 계산한 금액입니다.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),

          // 수정 버튼
          Positioned(
            left: 17,
            right: 17,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy ? null : _editExpense,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '수정',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// 상세 정보 행
// ==================================================

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF8791A3), fontSize: 12),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF20242D),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// 지출 수정 Bottom Sheet
// ==================================================

class _ExpenseEditSheet extends StatefulWidget {
  const _ExpenseEditSheet({required this.expense});

  final Expense expense;

  @override
  State<_ExpenseEditSheet> createState() => _ExpenseEditSheetState();
}

class _ExpenseEditSheetState extends State<_ExpenseEditSheet> {
  static const Color primary = Color(0xFF3478EF);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _placeController;
  late final TextEditingController _amountController;

  late String _category;
  late String _paymentMethod;

  @override
  void initState() {
    super.initState();

    _placeController = TextEditingController(text: widget.expense.place);
    _amountController = TextEditingController(
      text: widget.expense.amount.toString(),
    );

    _category = widget.expense.category;
    _paymentMethod = widget.expense.paymentMethod;
  }

  @override
  void dispose() {
    _placeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', ''),
    );

    // copyWith에서 날짜, 환율, 통화는 변경하지 않는다.
    final updated = widget.expense.copyWith(
      place: _placeController.text.trim(),
      category: _category,
      amount: amount,
      paymentMethod: _paymentMethod,
    );

    Navigator.pop(context, updated);
  }

  InputDecoration _decoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF5F7FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE5E9F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE5E9F0)),
      ),
    );
  }

  Widget _buildSelectField({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E9F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: primary, size: 20),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF303846),
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF8791A3),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCategory() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailOptionPickerSheet(
        title: '카테고리 선택',
        selectedValue: _category,
        options: [
          for (final category in categoryIcons.keys)
            _DetailPickerOption(
              value: category,
              label: category,
              icon: iconOfCategory(category),
            ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() => _category = result);
    }
  }

  Future<void> _selectPaymentMethod() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailOptionPickerSheet(
        title: '결제수단 선택',
        selectedValue: _paymentMethod,
        options: const [
          _DetailPickerOption(
            value: 'cash',
            label: '현금',
            icon: Icons.payments_outlined,
          ),
          _DetailPickerOption(
            value: 'card',
            label: '카드',
            icon: Icons.credit_card_rounded,
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() => _paymentMethod = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        20,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '지출 수정하기',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                '날짜와 결제 당시 환율은 변경되지 않습니다.',
                style: TextStyle(color: Color(0xFF8791A3), fontSize: 12),
              ),

              const SizedBox(height: 23),

              const _EditLabel('사용처'),
              TextFormField(
                controller: _placeController,
                maxLength: 50,
                decoration: _decoration(hint: '사용처를 입력하세요.'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '사용처를 입력해 주세요.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 13),

              const _EditLabel('카테고리'),
              _buildSelectField(
                icon: iconOfCategory(_category),
                label: _category,
                onTap: _selectCategory,
              ),

              const SizedBox(height: 17),

              _EditLabel('금액 (${expense.currency})'),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _decoration(hint: '금액을 입력하세요.'),
                validator: (value) {
                  final amount = double.tryParse(
                    (value ?? '').trim().replaceAll(',', ''),
                  );

                  if (amount == null || amount <= 0) {
                    return '올바른 금액을 입력해 주세요.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 17),

              const _EditLabel('결제수단'),
              _buildSelectField(
                icon: _paymentMethod == 'cash'
                    ? Icons.payments_outlined
                    : Icons.credit_card_rounded,
                label: _paymentMethod == 'cash' ? '현금' : '카드',
                onTap: _selectPaymentMethod,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '변경사항 저장',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditLabel extends StatelessWidget {
  const _EditLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DetailPickerOption {
  const _DetailPickerOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

class _DetailOptionPickerSheet extends StatelessWidget {
  const _DetailOptionPickerSheet({
    required this.title,
    required this.selectedValue,
    required this.options,
  });

  final String title;
  final String selectedValue;
  final List<_DetailPickerOption> options;

  static const Color primary = Color(0xFF3478EF);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 13, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1E5EC),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF20242D),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF8791A3),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final selected = option.value == selectedValue;

                    return InkWell(
                      onTap: () => Navigator.pop(context, option.value),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFEAF0FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? primary : const Color(0xFFE8ECF3),
                            width: selected ? 1.3 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFDCE7FF)
                                    : const Color(0xFFF3F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                option.icon,
                                color: selected
                                    ? primary
                                    : const Color(0xFF697589),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: selected
                                      ? primary
                                      : const Color(0xFF303846),
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: primary,
                                size: 21,
                              )
                            else
                              const Icon(
                                Icons.circle_outlined,
                                color: Color(0xFFD5DBE5),
                                size: 21,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF596579),
                    side: const BorderSide(color: Color(0xFFE5E9F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text(
                    '닫기',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
