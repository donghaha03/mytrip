import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../models/country.dart';
import '../models/spending_summary.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'category_charts.dart';
import 'expense_tile.dart';
import 'quick_converter.dart';
import 'trip_card.dart';

/// Interactive examples use isolated data, never the user's trip store.
class OnboardingExample extends StatefulWidget {
  const OnboardingExample({super.key, required this.step});
  final int step;
  @override
  State<OnboardingExample> createState() => _OnboardingExampleState();
}

class _OnboardingExampleState extends State<OnboardingExample> {
  bool _done = false, _deleted = false, _edited = false;
  int _previewRun = 0, _receiptStage = 0;
  late final _trip = Trip(
    id: 'guide-trip',
    name: '일본 여행',
    country: countryByIso('JP')!,
    start: DateTime(2027, 5, 1),
    end: DateTime(2027, 5, 5),
    budgetKrw: 1000000,
    expenses: widget.step == 4
        ? [
            Expense(
              id: 'guide-food',
              icon: '🍜',
              place: '이치란 라멘',
              amount: 1200,
              currency: 'JPY',
              category: '식비',
              date: DateTime(2027, 5, 1),
            ),
            Expense(
              id: 'guide-transport',
              icon: '🚃',
              place: 'JR 패스',
              amount: 3500,
              currency: 'JPY',
              category: '교통',
              date: DateTime(2027, 5, 1),
            ),
          ]
        : [],
  );

  @override
  Widget build(BuildContext context) {
    final summary = SpendingSummary(_trip);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_back_rounded, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      [
                        '여행 추가',
                        '지출 기록',
                        '내 여행',
                        '영수증 촬영',
                        '지출 한눈에 보기',
                      ][widget.step],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...switch (widget.step) {
                0 => [
                  _field('여행 이름', '도쿄 여행'),
                  _field('여행 국가', '일본'),
                  _field('여행 기간', '2027.05.01 – 05.05'),
                  _field('여행 예산', '1,000,000원'),
                  FilledButton.icon(
                    onPressed: () => setState(() => _done = !_done),
                    icon: Icon(_done ? Icons.check_rounded : Icons.add_rounded),
                    label: Text(_done ? '여행 추가 완료 · 다시 보기' : '여행 추가'),
                  ),
                ],
                1 => [
                  if (!_done) ...[
                    _field('금액 (JPY)', '1,200'),
                    Text(
                      RateApi.quotedKrw('JPY') > 0
                          ? '원화 환산 ${formatWon(RateApi.toKrw(1200, 'JPY'))}'
                          : '환율을 불러오면 원화로 환산해요',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field('사용처', '이치란 라멘'),
                    const Row(
                      children: [
                        Chip(label: Text('식비')),
                        SizedBox(width: 8),
                        Chip(label: Text('카드')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '면세라면 세금이 빠진 실제 결제액을 입력해요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else
                    ExpenseTile(
                      trip: _trip,
                      expense: Expense(
                        id: 'guide-expense',
                        icon: '🍜',
                        place: '이치란 라멘',
                        amount: 1200,
                        currency: 'JPY',
                        category: '식비',
                        paymentMethod: PaymentMethod.card,
                        date: DateTime(2027, 5, 1),
                      ),
                      interactive: false,
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => setState(() => _done = !_done),
                    icon: Icon(_done ? Icons.check_rounded : Icons.add_rounded),
                    label: Text(_done ? '기록 완료 · 다시 보기' : '저장'),
                  ),
                ],
                2 => [
                  if (_deleted)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text('예시 여행을 삭제했어요', textAlign: TextAlign.center),
                    )
                  else
                    TripCard(
                      key: ValueKey('guide-preview-$_previewRun'),
                      trip: _trip,
                      previewSwipe: _previewRun > 0,
                      onTap: () {},
                      onLongPress: () => setState(() {
                        _trip.name = '도쿄 여행';
                        _edited = true;
                      }),
                      onDelete: () => setState(() => _deleted = true),
                    ),
                  const SizedBox(height: 16),
                  if (!_deleted && !_edited)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swipe_left_alt_rounded,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '카드 위에서 왼쪽으로 천천히 밀고,\n나타난 수정·삭제 버튼을 눌러보세요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_edited && !_deleted)
                    const Text('여행 이름을 수정했어요', textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => setState(() {
                      _deleted = false;
                      _edited = false;
                      _trip.name = '일본 여행';
                      _previewRun++;
                    }),
                    child: Text(
                      _deleted || _edited ? '처음부터 해보기' : '스와이프 예시 보기',
                    ),
                  ),
                ],
                3 => [
                  if (_receiptStage < 2)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _receiptStage == 0
                                ? Icons.document_scanner_outlined
                                : Icons.receipt_long_outlined,
                            size: 32,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '여행지 카페',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 20),
                          const Text('커피       1       5,000'),
                          const Divider(height: 32),
                          const Text(
                            '결제금액   5,000원',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _field('상호명', '여행지 카페'),
                    _field('결제금액', '5,000원'),
                    _field('결제 통화', 'KRW · 원'),
                    _field('결제일', '2027-05-01'),
                    const Text(
                      '내용을 확인하고 지출 양식에 적용해요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () =>
                        setState(() => _receiptStage = (_receiptStage + 1) % 3),
                    icon: Icon(
                      _receiptStage == 2
                          ? Icons.replay_rounded
                          : Icons.document_scanner_outlined,
                    ),
                    label: Text(
                      ['촬영해 보기', '사진 확인 후 인식', '다시 해보기'][_receiptStage],
                    ),
                  ),
                ],
                _ => [
                  Text(
                    summary.available
                        ? '총지출 ${formatWon(summary.netKrw)}'
                        : '환율 확인 필요',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (summary.available) ...[
                    CategoryPie(summary: summary),
                    for (final entry in summary.sorted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: categoryColor(entry.key),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${entry.key} ${(summary.share(entry.key) * 100).toStringAsFixed(1)}%',
                              ),
                            ),
                            Text(
                              formatWon(entry.value),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  QuickConverter(country: _trip.country),
                ],
              },
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '사용 예시',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(
        value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
