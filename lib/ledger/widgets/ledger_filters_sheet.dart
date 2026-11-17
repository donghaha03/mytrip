import 'package:flutter/material.dart';

import '../models/trip.dart';
import 'app_sheet.dart';

typedef LedgerFilters = ({
  String? payment,
  bool categories,
  bool byAmount,
  bool? imported,
});
const LedgerFilters defaultLedgerFilters = (
  payment: null,
  categories: false,
  byAmount: false,
  imported: null,
);

class LedgerFiltersSheet extends StatefulWidget {
  const LedgerFiltersSheet({
    super.key,
    required this.trip,
    required this.filters,
  });
  final Trip trip;
  final LedgerFilters filters;

  @override
  State<LedgerFiltersSheet> createState() => _LedgerFiltersSheetState();
}

class _LedgerFiltersSheetState extends State<LedgerFiltersSheet> {
  late LedgerFilters _value = widget.filters;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    child: AppSheet(
      title: '목록 설정',
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('결제수단'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final (value, label, count)
                        in <(String?, String, int)>[
                          (null, '전체', widget.trip.expenses.length),
                          for (final method in PaymentMethod.values)
                            (
                              method.name,
                              method.label,
                              widget.trip.expenses
                                  .where((e) => e.paymentMethod == method)
                                  .length,
                            ),
                          if (widget.trip.expenses.any(
                            (e) => e.paymentMethod == null,
                          ))
                            (
                              'unknown',
                              '미지정',
                              widget.trip.expenses
                                  .where((e) => e.paymentMethod == null)
                                  .length,
                            ),
                        ])
                      ChoiceChip(
                        key: ValueKey('ledger-payment-${value ?? 'all'}'),
                        label: Text('$label $count'),
                        selected: _value.payment == value,
                        onSelected: (_) => setState(
                          () => _value = (
                            payment: value,
                            categories: _value.categories,
                            byAmount: _value.byAmount,
                            imported: _value.imported,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('보기 방식'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (value, label) in [
                      (false, '날짜별'),
                      (true, '카테고리별'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _value.categories == value,
                        onSelected: (_) => setState(
                          () => _value = (
                            payment: _value.payment,
                            categories: value,
                            byAmount: _value.byAmount,
                            imported: value ? _value.imported : null,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_value.categories) ...[
                  const SizedBox(height: 20),
                  const Text('정렬'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (value, label) in [
                        (true, '금액순'),
                        (false, '날짜순'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _value.byAmount == value,
                          onSelected: (_) => setState(
                            () => _value = (
                              payment: _value.payment,
                              categories: _value.categories,
                              byAmount: value,
                              imported: _value.imported,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('기록 방식'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final (value, label, key)
                          in <(bool?, String, String)>[
                            (null, '전체 기록', 'all'),
                            (true, '자동 기록', 'auto'),
                            (false, '직접 입력', 'manual'),
                          ])
                        ChoiceChip(
                          key: ValueKey('ledger-source-$key'),
                          label: Text(label),
                          selected: _value.imported == value,
                          onSelected: (_) => setState(
                            () => _value = (
                              payment: _value.payment,
                              categories: _value.categories,
                              byAmount: _value.byAmount,
                              imported: value,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _value = defaultLedgerFilters),
              child: const Text('초기화'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SheetPrimaryButton(
                label: '적용',
                onTap: () => Navigator.pop(context, _value),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
