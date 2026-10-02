import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api.dart';
import '../data/trip_store.dart';
import '../models/country.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sheet.dart';
import '../widgets/calendar_range_picker.dart';
import '../widgets/quick_converter.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/won_input_formatter.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, required this.trip, this.expense});

  final Trip trip;
  final Expense? expense;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _place;
  late final TextEditingController _amount;
  late final TextEditingController _memo;
  late Country _currency;
  late final String _id;
  late String _category;
  PaymentMethod? _paymentMethod;
  bool _isTaxFree = false;
  late DateTime _date;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _place = TextEditingController(text: e?.place ?? '');
    _memo = TextEditingController(text: e?.memo ?? '');
    _currency = countryByCode(e?.currency ?? '') ?? widget.trip.country;
    _amount = TextEditingController(
      text: e == null ? '' : formatNumber(e.amount.truncate()),
    );
    _id = e?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    _category = e?.category == '숙소' ? '숙박' : e?.category ?? '식비';
    if (!expenseCategoryIcons.containsKey(_category)) _category = '기타';
    _date = e?.date ?? DateTime.now();
    _paymentMethod = e?.paymentMethod;
    _isTaxFree = e?.isTaxFree ?? false;
  }

  @override
  void dispose() {
    _place.dispose();
    _amount.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    var selected = _date;
    final result = await showAppSheet<DateTime>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          child: AppSheet(
            title: '지출 날짜',
            children: [
              CalendarRangePicker(
                initialMonth: _date,
                initialRange: DateRange(_date, _date),
                singleDay: true,
                onChanged: (range) {
                  if (range != null) {
                    setSheetState(() => selected = range.start);
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(formatDate(selected), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              SheetPrimaryButton(
                label: '선택 완료',
                onTap: () => Navigator.of(sheetContext).pop(selected),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(
      () => _date = DateTime(
        result.year,
        result.month,
        result.day,
        _date.hour,
        _date.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
      helpText: '지출 시각',
      cancelText: '취소',
      confirmText: '선택',
      hourLabelText: '시',
      minuteLabelText: '분',
      errorInvalidText: '올바른 시간을 입력해주세요',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(
      () => _date = DateTime(
        _date.year,
        _date.month,
        _date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (RateApi.quotedKrw(_currency.currency) <= 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await tripStore.saveExpense(
        widget.trip.id,
        Expense(
          id: _id,
          icon: expenseCategoryIcons[_category]!,
          place: _place.text.trim(),
          amount: widget.expense?.isImported == true
              ? widget.expense!.amount
              : parseAmount(_amount.text).truncateToDouble(),
          date: _date,
          category: _category,
          paymentMethod: _paymentMethod,
          isTaxFree: _isTaxFree,
          currency: _currency.currency,
          memo: _memo.text.trim(),
          recordedQuote:
              widget.expense == null ||
                  widget.expense!.currencyOf(widget.trip) != _currency.currency
              ? RateApi.quotedKrw(_currency.currency)
              : widget.expense!.recordedQuote,
          source: widget.expense?.source,
          status: widget.expense?.status ?? ExpenseStatus.approved,
          originalAmount: widget.expense?.originalAmount,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = '저장하지 못했어요. 입력 내용을 유지했으니 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final deleted = await deleteExpenseWithConfirmation(
        context,
        widget.trip,
        widget.expense!,
      );
      if (deleted && mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = '삭제하지 못했어요. 기록은 그대로 유지됩니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: RateApi.changes,
    builder: (context, _) {
      final trip = widget.trip;
      final available = RateApi.quotedKrw(_currency.currency) > 0;
      final imported = widget.expense?.isImported ?? false;
      final amount = parseAmount(_amount.text);
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenTopBar(
                title: widget.expense == null ? '지출 기록' : '지출 수정',
                trailing: widget.expense == null
                    ? null
                    : IconButton(
                        tooltip: '지출 삭제',
                        onPressed: _busy ? null : _delete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.danger,
                        ),
                      ),
              ),
              Expanded(
                child: Form(
                  key: _form,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${trip.country.flag} ${trip.name}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (imported) ...[
                          const Text(
                            '자동 기록의 금액·통화·사용처·일시는 바꿀 수 없어요. 분류·면세·메모는 수정할 수 있어요.',
                          ),
                          const SizedBox(height: 16),
                        ],
                        DropdownButtonFormField<String>(
                          key: const ValueKey('expense-currency'),
                          initialValue: _currency.currency,
                          isExpanded: true,
                          menuMaxHeight: 320,
                          decoration: _decoration('결제 통화'),
                          items: [
                            for (final c in [
                              trip.country,
                              if (trip.country.currency != 'KRW') kKrwCountry,
                              ...kExpenseCurrencies.where(
                                (c) =>
                                    c.currency != trip.country.currency &&
                                    c.currency != 'KRW',
                              ),
                            ])
                              DropdownMenuItem(
                                value: c.currency,
                                child: Text(
                                  '${c.flag} ${c.currency} · ${c.unitLabel}',
                                ),
                              ),
                          ],
                          onChanged: _busy || imported
                              ? null
                              : (code) => setState(() {
                                  _currency = countryByCode(code!)!;
                                }),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('expense-amount'),
                          controller: _amount,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          enabled: !_busy && !imported,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            TextInputFormatter.withFunction(
                              (oldValue, newValue) =>
                                  newValue.text.contains('-')
                                  ? oldValue
                                  : const AmountInputFormatter()
                                        .formatEditUpdate(oldValue, newValue),
                            ),
                          ],
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: _decoration('금액 (${_currency.currency})')
                              .copyWith(
                                prefixText: '${_currency.symbol} ',
                                hintText: '0',
                              ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (imported) return null;
                            final parsed = parseAmount(value ?? '');
                            return parsed.isFinite && parsed.truncate() > 0
                                ? null
                                : '금액은 1 이상 입력해주세요';
                          },
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                available
                                    ? '원화 환산 ${formatWon(RateApi.toKrw(amount, _currency.currency))}'
                                    : '환율을 불러오면 기록할 수 있어요',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${currentRateLabel(_currency)} · 소수점은 버려요',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          key: const ValueKey('expense-place'),
                          controller: _place,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          enabled: !_busy && !imported,
                          maxLength: 50,
                          textInputAction: TextInputAction.done,
                          decoration: _decoration(
                            '사용처',
                          ).copyWith(hintText: '예: 이치란 라멘'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? '사용처를 입력해주세요'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '결제수단',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        FormField<PaymentMethod>(
                          initialValue: _paymentMethod,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) =>
                              value == null ? '결제수단을 선택해주세요' : null,
                          builder: (field) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final method in PaymentMethod.values)
                                    ChoiceChip(
                                      label: Text(method.label),
                                      selected: field.value == method,
                                      onSelected: _busy || imported
                                          ? null
                                          : (_) {
                                              field.didChange(method);
                                              setState(
                                                () => _paymentMethod = method,
                                              );
                                            },
                                    ),
                                ],
                              ),
                              if (field.hasError)
                                Text(
                                  field.errorText!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('면세 적용'),
                          subtitle: const Text('면세 처리 후 실제 결제액을 입력하세요.'),
                          value: _isTaxFree,
                          onChanged: _busy
                              ? null
                              : (value) => setState(() => _isTaxFree = value),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '카테고리',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final category in expenseCategoryIcons.entries)
                              ChoiceChip(
                                label: Text(
                                  '${category.value} ${category.key}',
                                ),
                                selected: _category == category.key,
                                onSelected: _busy
                                    ? null
                                    : (_) => setState(
                                        () => _category = category.key,
                                      ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '날짜 · 시각',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _busy || imported ? null : _pickDate,
                              icon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                              ),
                              label: Text(formatDate(_date)),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy || imported ? null : _pickTime,
                              icon: const Icon(
                                Icons.schedule_rounded,
                                size: 18,
                              ),
                              label: Text(
                                '${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          key: const ValueKey('expense-memo'),
                          controller: _memo,
                          enabled: !_busy,
                          maxLength: 300,
                          maxLines: 3,
                          decoration: _decoration('메모 (선택)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _busy || !available ? null : _save,
                  child: Text(
                    _busy ? '저장 중…' : '저장',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<bool> deleteExpenseWithConfirmation(
  BuildContext context,
  Trip trip,
  Expense expense,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('이 지출을 삭제할까요?'),
      content: Text(
        expense.isImported
            ? '${expense.place}\n장부에서 숨기며 실제 카드 결제를 취소하지는 않아요.'
            : expense.place,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('삭제', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  await tripStore.deleteExpense(trip.id, expense.id);
  return true;
}
