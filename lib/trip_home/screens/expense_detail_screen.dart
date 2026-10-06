import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../data/trip_store.dart';
import '../models/country.dart';
import '../models/trip.dart';
import '../receipts/receipt_client.dart';
import '../receipts/receipt_consent.dart';
import '../receipts/receipt_platform.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/quick_converter.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/receipt_items.dart';
import 'expense_form_screen.dart';

class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({
    super.key,
    required this.trip,
    required this.expenseId,
    this.receiptClient,
  });
  final Trip trip;
  final String expenseId;
  final ReceiptClient? receiptClient;

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  bool _busy = false;
  String? _error;
  ReceiptClient? _receiptClient;
  ReceiptClient get _client =>
      _receiptClient ??= widget.receiptClient ?? ReceiptClient();

  @override
  void dispose() {
    _receiptClient?.close();
    super.dispose();
  }

  Future<List<String>?> _translate(Expense expense, String language) async {
    final connection = await _client.connection(configUrl: receiptConfigUrl);
    if (connection?.isGemini != true) {
      throw const ReceiptConnectionException('품목 번역 서버가 연결되지 않았어요.');
    }
    if (await receiptConsent(connection!.url) != true) {
      if (!mounted) return null;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => ReceiptConsentScreen(
            url: connection.url,
            onDecision: (value) => Navigator.of(context).pop(value),
          ),
        ),
      );
      if (!mounted || await receiptConsent(connection.url) != true) return null;
    }
    return _client.translate(
      connection,
      expense.receiptItems.map((item) => item.name).toList(),
      language,
    );
  }

  Future<void> _delete(Expense expense) async {
    setState(() => _busy = true);
    try {
      final deleted = await deleteExpenseWithConfirmation(
        context,
        widget.trip,
        expense,
      );
      if (deleted && mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = '삭제하지 못했어요. 기록은 그대로 유지됩니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([tripStore, RateApi.changes]),
    builder: (context, _) {
      final trip = widget.trip;
      final e = trip.expenses
          .where((e) => e.id == widget.expenseId)
          .firstOrNull;
      if (e == null) {
        return const Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                ScreenTopBar(title: '지출 상세'),
                Expanded(child: Center(child: Text('삭제되었거나 찾을 수 없는 기록이에요'))),
              ],
            ),
          ),
        );
      }
      final code = e.currencyOf(trip);
      final currency = countryByCode(code);
      final quote = RateApi.quotedKrw(code);
      final amount = e.status.countsAsSpending ? e.amount : 0;
      final adjustments = e.receiptAdjustments;
      String adjustmentAmount(double? value) => value == null
          ? '확인된 금액 없음'
          : '${formatNumber(value)} ${adjustments?.currency ?? '통화 확인 필요'}';
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenTopBar(
                title: '지출 상세',
                trailing: IconButton(
                  tooltip: '지출 삭제',
                  onPressed: _busy ? null : () => _delete(e),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.icon, style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 12),
                          Text(
                            e.place,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${e.category} · ${e.paymentMethod?.label ?? '미지정'}${e.isTaxFree ? ' · 면세' : ''}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '${currency?.formatForeign(amount) ?? formatNumber(amount.truncate())} $code',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            quote > 0 || !e.status.countsAsSpending
                                ? '현재 환산 ${formatWon(e.krwOf(trip))}'
                                : '환율 없음',
                            style: const TextStyle(
                              fontSize: 18,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (e.receiptItems.isNotEmpty)
                      ReceiptItems(
                        items: e.receiptItems,
                        currency: code,
                        onTranslate: (language) => _translate(e, language),
                      ),
                    _Info(
                      '날짜 · 시각',
                      '${formatDate(e.date)} ${e.date.hour.toString().padLeft(2, '0')}:${e.date.minute.toString().padLeft(2, '0')}',
                    ),
                    _Info('결제수단', e.paymentMethod?.label ?? '미지정'),
                    _Info('결제 상태', e.status.label),
                    if (e.originalAmount != null && e.originalAmount != amount)
                      _Info(
                        '승인 당시 금액',
                        '${currency?.formatForeign(e.originalAmount!) ?? formatNumber(e.originalAmount!)} $code',
                      ),
                    if (e.isImported)
                      _Info(
                        '기록 방식',
                        e.source == 'demo-card'
                            ? '테스트 카드 · 실제 결제 아님'
                            : '카드 자동 기록',
                      ),
                    _Info('면세', e.isTaxFree ? '적용 · 실제 결제액 기준' : '미적용'),
                    for (final tax in e.receiptTaxes)
                      _Info(
                        tax.label,
                        '${formatNumber(tax.amount)} ${tax.currency}\n${tax.inclusionLabel}',
                      ),
                    if (e.receiptFingerprint != null && e.receiptTaxes.isEmpty)
                      const _Info('소비세 · 부가세', '저장된 세금 정보 없음'),
                    if (e.receiptFingerprint != null ||
                        adjustments != null) ...[
                      for (final line in adjustments?.details ?? const [])
                        _Info(
                          '${line.label} · ${line.isDiscount ? '할인' : '추가금'}',
                          '${line.isDiscount ? '−' : '+'}${formatNumber(line.amount)} ${line.currency}',
                        ),
                      _Info('면세액', adjustmentAmount(adjustments?.exemptedTax)),
                      if (adjustments?.taxFreeBase != null)
                        _Info(
                          '면세 대상 금액',
                          adjustmentAmount(adjustments!.taxFreeBase),
                        ),
                      if (adjustments?.details.any((line) => line.isDiscount) !=
                          true)
                        _Info('할인액', adjustmentAmount(adjustments?.discount))
                      else if (adjustments?.discount != null &&
                          adjustments!.details
                                  .where((line) => line.isDiscount)
                                  .length >
                              1)
                        _Info('할인 합계', adjustmentAmount(adjustments.discount)),
                    ],
                    if (e.status == ExpenseStatus.partiallyCancelled)
                      _Info(
                        '취소 후 결제액',
                        '${currency?.formatForeign(e.amount) ?? formatNumber(e.amount)} $code',
                      ),
                    _Info(
                      '최종 금액',
                      '${currency?.formatForeign(amount) ?? formatNumber(amount)} $code',
                    ),
                    const Divider(height: 32),
                    const Text(
                      '기록 당시와 현재 환율',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _Info(
                      '기록 당시',
                      e.recordedQuote == null
                          ? '저장된 환율 없음'
                          : '${formatNumber(currency?.unitAmount ?? 1)} $code = ${formatWon(e.recordedQuote!)}',
                    ),
                    _Info(
                      '현재 기준',
                      currency == null
                          ? '지원하지 않는 통화'
                          : currentRateLabel(currency),
                    ),
                    const Text(
                      '합계와 빠른 환산은 현재 표시 환율을 사용해요. 카드사 청구액·수수료와는 다를 수 있어요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (e.memo.isNotEmpty) ...[
                      const Divider(height: 32),
                      const Text(
                        '메모',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(e.memo),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ExpenseFormScreen(trip: trip, expense: e),
                        ),
                      );
                      if (context.mounted &&
                          !trip.expenses.any((item) => item.id == e.id)) {
                        Navigator.of(context).pop();
                      }
                    },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: Text(e.isImported ? '분류 · 메모 수정' : '수정'),
            ),
          ),
        ),
      );
    },
  );
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
