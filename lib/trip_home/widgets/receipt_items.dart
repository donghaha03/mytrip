import 'package:flutter/material.dart';

import '../models/receipt_item.dart';
import '../theme/app_theme.dart';

class ReceiptItems extends StatelessWidget {
  const ReceiptItems({
    super.key,
    required this.items,
    required this.currency,
    this.onChanged,
  });
  final List<ReceiptItem> items;
  final String currency;
  final ValueChanged<List<ReceiptItem>>? onChanged;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(
      '품목 상세 (${items.length})',
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: onChanged == null
              ? ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(items[i].name),
                  subtitle: Text(
                    '수량 ${items[i].quantity}${items[i].unitPrice == null ? '' : ' · 단가 ${formatNumber(items[i].unitPrice!)} $currency'}',
                  ),
                  trailing: Text('${formatNumber(items[i].amount)} $currency'),
                )
              : Column(
                  children: [
                    if (items[i].unitPrice != null)
                      Text(
                        '인식한 단가 ${formatNumber(items[i].unitPrice!)} $currency',
                      ),
                    TextFormField(
                      initialValue: items[i].name,
                      decoration: const InputDecoration(labelText: '품목명'),
                      maxLength: 100,
                      onChanged: (name) => _change(i, name: name),
                      validator: (s) =>
                          s?.trim().isNotEmpty == true ? null : '품목명을 확인해주세요',
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: items[i].quantity.toString(),
                            decoration: const InputDecoration(labelText: '수량'),
                            keyboardType: TextInputType.number,
                            onChanged: (s) =>
                                _change(i, quantity: int.tryParse(s) ?? 0),
                            validator: (s) =>
                                (int.tryParse(s ?? '') ?? 0) > 0 &&
                                    (int.tryParse(s ?? '') ?? 0) <= 999
                                ? null
                                : '1~999로 입력해주세요',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: items[i].amount.truncate().toString(),
                            decoration: InputDecoration(
                              labelText: '금액 ($currency)',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (s) => _change(
                              i,
                              amount: double.tryParse(s) ?? double.nan,
                            ),
                            validator: (s) =>
                                RegExp(r'^\d+$').hasMatch(s ?? '') &&
                                    (double.tryParse(s ?? '') ?? double.nan)
                                        .isFinite
                                ? null
                                : '금액을 확인해주세요',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      if (onChanged != null)
        TextButton(
          onPressed: () => onChanged!([]),
          child: const Text('품목 정보 제외'),
        ),
    ],
  );

  void _change(int index, {String? name, int? quantity, double? amount}) {
    final updated = [...items];
    final old = items[index];
    updated[index] = ReceiptItem(
      name: name ?? old.name,
      quantity: quantity ?? old.quantity,
      amount: amount ?? old.amount,
      unitPrice: quantity == null && amount == null ? old.unitPrice : null,
    );
    onChanged!(updated);
  }
}
