import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/receipt_item.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../receipts/receipt_client.dart';

class ReceiptItems extends StatefulWidget {
  const ReceiptItems({
    super.key,
    required this.items,
    required this.currency,
    this.onChanged,
    this.onTranslate,
  });
  final List<ReceiptItem> items;
  final String currency;
  final ValueChanged<List<ReceiptItem>>? onChanged;
  final Future<List<String>?> Function(String language)? onTranslate;

  @override
  State<ReceiptItems> createState() => _ReceiptItemsState();
}

class _ReceiptItemsState extends State<ReceiptItems> {
  List<ReceiptItem> get items => widget.items;
  String get currency => widget.currency;
  ValueChanged<List<ReceiptItem>>? get onChanged => widget.onChanged;
  final _translations = <String, List<String>>{};
  String? _language, _error;
  bool _busy = false;

  @override
  void didUpdateWidget(ReceiptItems oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(
      oldWidget.items.map((item) => item.name).toList(),
      items.map((item) => item.name).toList(),
    )) {
      _translations.clear();
      _language = null;
      _error = null;
    }
  }

  Future<void> _translate(String language) async {
    if (_busy) return;
    if (_language == language || _translations.containsKey(language)) {
      setState(() {
        _language = _language == language ? null : language;
        _error = null;
      });
      return;
    }
    final names = items.map((item) => item.name).toList();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final translated = await widget.onTranslate!(language);
      if (!mounted ||
          !listEquals(names, items.map((item) => item.name).toList())) {
        return;
      }
      if (translated == null) return; // Consent cancelled; keep the original.
      if (translated.length != items.length) throw const FormatException();
      setState(() {
        _translations[language] = translated;
        _language = language;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ReceiptConnectionException
              ? error.message
              : '번역하지 못했어요. 원문은 그대로예요. 다시 시도해주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(
      '품목 상세 (${items.length})',
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    children: [
      if (onChanged == null && widget.onTranslate != null)
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '번역하기',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              for (final language in ['ko', 'en'])
                Tooltip(
                  message: '${language == 'ko' ? '한국어' : '영어'}로 번역 · 다시 누르면 원문',
                  child: ChoiceChip(
                    label: Text(language == 'ko' ? '한국어' : 'English'),
                    selected: _language == language,
                    onSelected: _busy ? null : (_) => _translate(language),
                  ),
                ),
              if (_busy) const Text('번역 중…', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: AppColors.danger)),
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: onChanged == null
              ? ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _language == null
                        ? items[i].name
                        : _translations[_language]![i],
                  ),
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
