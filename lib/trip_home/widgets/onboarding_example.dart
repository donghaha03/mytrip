import 'package:flutter/material.dart';

import '../models/country.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
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
  late final _trip = Trip(
    id: 'guide-trip',
    name: '일본 여행',
    country: countryByIso('JP')!,
    start: DateTime(2027, 5, 1),
    end: DateTime(2027, 5, 5),
    budgetKrw: 1000000,
  );

  @override
  Widget build(BuildContext context) => Column(
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
                    ['여행 추가', '지출 기록', '내 여행', '영수증 촬영'][widget.step],
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
                _field('여행 국가', '일본'),
                _field('여행 기간', '2027.05.01 – 05.05'),
                _field('여행 예산', '1,000,000원'),
                FilledButton.icon(
                  onPressed: () => setState(() => _done = !_done),
                  icon: Icon(_done ? Icons.check_rounded : Icons.add_rounded),
                  label: Text(_done ? '일본 여행 준비 완료' : '여행 추가해보기'),
                ),
              ],
              1 => [
                _field('사용처', '여행지 카페'),
                _field('결제금액', '500 JPY'),
                const Row(
                  children: [
                    Chip(label: Text('식비')),
                    SizedBox(width: 8),
                    Chip(label: Text('카드')),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => setState(() => _done = !_done),
                  icon: Icon(_done ? Icons.check_rounded : Icons.add_rounded),
                  label: Text(_done ? '지출 1건 기록 완료' : '지출 기록해보기'),
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
                    trip: _trip,
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
                          '위 카드를 왼쪽으로 밀어보세요',
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
                  }),
                  child: const Text('다시 해보기'),
                ),
              ],
              _ => [
                if (!_done)
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
                    child: const Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 32,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '여행지 카페',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 20),
                        Text('커피       1       5,000'),
                        Divider(height: 32),
                        Text(
                          '결제금액   5,000원',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _field('상호명', '여행지 카페'),
                  _field('결제금액', '5,000원'),
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
                  onPressed: () => setState(() => _done = !_done),
                  icon: Icon(
                    _done
                        ? Icons.replay_rounded
                        : Icons.document_scanner_outlined,
                  ),
                  label: Text(_done ? '다시 해보기' : '촬영 흐름 보기'),
                ),
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

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Divider(height: 16),
      ],
    ),
  );
}
