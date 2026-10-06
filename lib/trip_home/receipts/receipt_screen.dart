import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/receipt_items.dart';
import '../models/receipt_item.dart';
import '../models/country.dart';
import '../models/trip.dart';
import 'receipt_draft.dart';
import 'receipt_platform.dart';
import 'receipt_client.dart';
import 'receipt_consent.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, this.client});
  final ReceiptClient? client;
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late final _client = widget.client ?? ReceiptClient();
  final _accessCode = TextEditingController();
  ReceiptConnection? _connection;
  ReceiptDraft? _draft;
  String? _imageData;
  Uint8List? _image;
  String? _error;
  bool _configured = false, _busy = false, _consented = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  @override
  void dispose() {
    closeReceiptCamera();
    _client.close();
    _accessCode.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    _connection = await _client.connection(
      localRuntime: getReceiptRuntime(),
      configUrl: receiptConfigUrl,
    );
    _configured = true;
  }

  Future<bool> _checkConsent({bool manage = false}) async {
    final connection = _connection;
    if (connection?.isGemini != true) return true;
    if (!manage && await receiptConsent(connection!.url) == true) {
      _consented = true;
      return true;
    }
    if (!mounted) return false;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ReceiptConsentScreen(
          url: connection!.url,
          onDecision: (value) => Navigator.of(context).pop(value),
        ),
      ),
    );
    final approved = await receiptConsent(connection!.url) == true;
    if (!mounted) return false;
    setState(() => _consented = approved);
    return _consented;
  }

  Future<void> _retryConnection() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _consented = false;
      _error = null;
    });
    try {
      await _connect();
      if (_connection == null) {
        throw const ReceiptConnectionException(
          '영수증 서버가 아직 연결되지 않았어요. 수동 입력을 이용해주세요.',
        );
      }
      await _checkConsent();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(ReceiptDraft draft) async {
    final result = await Navigator.of(context).push<ReceiptDraft>(
      MaterialPageRoute(
        builder: (_) => ReceiptReviewScreen(draft: draft, image: _image!),
      ),
    );
    if (mounted && result != null) Navigator.of(context).pop(result);
  }

  Future<void> _capture({bool gallery = false}) async {
    if (_busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      if (!_configured) {
        try {
          await _connect();
        } on ReceiptConnectionException catch (error) {
          _error = error.message;
        }
      }
      if (!mounted) return;
      // Keep repeat gallery clicks in the user's gesture for mobile browsers.
      if (!_consented && !await _checkConsent()) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final raw = await openReceiptCamera(
        captureOnly: !_configured || _connection != null,
        gallery: gallery,
      );
      if (!mounted) return;
      if (raw == null) {
        if (_image == null) Navigator.of(context).pop();
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final image = data['image'] as String;
      if (image.length > 12000000 || !image.startsWith('data:image/')) {
        throw const FormatException();
      }
      setState(() {
        _imageData = image;
        _image = base64Decode(image.split(',').last);
        if (_connection?.isGemini != true) _consented = false;
        _draft = null;
      });
      if (_configured && _connection == null && data['text'] is String) {
        _draft = ReceiptDraft.parse(
          data['text'] as String,
          confidence: (data['confidence'] as num).toDouble(),
        );
        await _review(_draft!);
      } else if (_connection == null) {
        setState(
          () => _error ??=
              'LLM 영수증 서버가 아직 연결되지 않았어요. 서버 설정 후 재시도하거나 수동으로 입력해주세요.',
        );
      } else if (_connection!.isGemini) {
        setState(() => _busy = false);
        await _recognize();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ReceiptConnectionException
              ? error.message
              : error is PlatformException
              ? error.message ?? '촬영하지 못했어요. 권한을 확인하거나 사진을 선택해주세요.'
              : '사진을 열지 못했어요. 다시 촬영하거나 사진 선택·수동 입력을 이용해주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recognize() async {
    if (_busy || _imageData == null) return;
    if (_draft != null) {
      setState(() => _busy = true);
      try {
        await _review(_draft!);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    if (!_consented || _connection == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await _client.recognize(
        _connection!,
        _imageData!,
        accessCode: _accessCode.text.trim(),
      );
      if (mounted) {
        setState(() => _draft = draft);
        await _review(draft);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ReceiptConnectionException
              ? error.message
              : '인식하지 못했어요. 다시 시도하거나 수동으로 입력해주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          ScreenTopBar(title: _image == null ? '영수증 촬영' : '영수증 사진 확인'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_image != null) ...[
                  Image.memory(
                    _image!,
                    height: MediaQuery.sizeOf(context).height * .38,
                    fit: BoxFit.contain,
                    semanticLabel: '촬영한 영수증 원본',
                  ),
                  const SizedBox(height: 16),
                  if (_draft == null &&
                      _connection != null &&
                      !_connection!.isGemini) ...[
                    const Text('사진 전체를 OpenAI로 보내 내용을 읽어요. 인식 후 직접 확인하고 저장해요.'),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://developers.openai.com/api/docs/guides/your-data',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text('OpenAI 데이터 보관 정책'),
                    ),
                    if (_connection?.needsAccessCode == true)
                      TextField(
                        controller: _accessCode,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: '접속 코드',
                          helperText: '서버 관리자가 공유한 코드예요. API 키는 입력하지 마세요.',
                          helperMaxLines: 2,
                        ),
                      ),
                    if (_connection?.csrf != null)
                      TextButton(
                        onPressed: () => launchUrl(
                          _connection!.url.resolve('/receipt-connect'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('ChatGPT 연결 관리'),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _consented,
                      title: const Text('이 사진을 OpenAI로 보내는 데 동의해요'),
                      onChanged: _busy
                          ? null
                          : (value) =>
                                setState(() => _consented = value ?? false),
                    ),
                  ],
                  if (_draft == null && _connection == null)
                    OutlinedButton(
                      onPressed: _busy ? null : _retryConnection,
                      child: const Text('서버 연결 다시 확인'),
                    ),
                ],
                if (_busy) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 12),
                  Text(
                    _image == null ? '영수증 촬영 화면을 열고 있어요…' : '영수증 사진을 읽고 있어요…',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                if (_image != null)
                  FilledButton(
                    onPressed:
                        !_busy &&
                            (_draft != null ||
                                (_consented && _connection != null))
                        ? _recognize
                        : null,
                    child: Text(
                      _draft != null
                          ? '인식한 내용 확인'
                          : _error == null
                          ? '이 사진으로 인식'
                          : '인식 재시도',
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _capture,
                        child: Text(_image == null ? '촬영 다시 시도' : '재촬영'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _capture(gallery: true),
                        child: const Text('사진 선택'),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('수동 입력으로 돌아가기'),
                ),
                if (_connection?.isGemini == true)
                  TextButton(
                    onPressed: _busy ? null : () => _checkConsent(manage: true),
                    child: const Text('사진 전송 동의'),
                  ),
              ],
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
  });
  final ReceiptDraft draft;
  final Uint8List image;
  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

/// Compact input accepts YYYYMd, YYYYMMd / YYYYMdd, and YYYYMMDD.
/// For seven digits prefer the two-digit month when both readings are valid.
DateTime? parsePaymentDate(String value) {
  final input = value.trim();
  DateTime? valid(int year, int month, int day) {
    if (year < 1 || year > 9999) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  final separated = RegExp(
    r'^(\d{4})[-./](\d{1,2})[-./](\d{1,2})$',
  ).firstMatch(input);
  if (separated != null) {
    return valid(
      int.parse(separated[1]!),
      int.parse(separated[2]!),
      int.parse(separated[3]!),
    );
  }
  if (!RegExp(r'^\d{6,8}$').hasMatch(input)) return null;
  final year = int.parse(input.substring(0, 4));
  for (final monthLength
      in input.length == 6
          ? [1]
          : input.length == 8
          ? [2]
          : [2, 1]) {
    final date = valid(
      year,
      int.parse(input.substring(4, 4 + monthLength)),
      int.parse(input.substring(4 + monthLength)),
    );
    if (date != null) return date;
  }
  return null;
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
  String? _itemError;
  late var _items = [...widget.draft.items];
  late var _taxes = [...widget.draft.taxes];
  late var _adjustments = widget.draft.adjustments;
  final _dateFocus = FocusNode();
  DateTime? get _parsedDate => parsePaymentDate(_date.text);

  @override
  void initState() {
    super.initState();
    _dateFocus.addListener(_dateFocusChanged);
  }

  void _dateFocusChanged() {
    if (!_dateFocus.hasFocus) _normalizeDate();
  }

  void _normalizeDate() {
    final date = _parsedDate;
    if (date == null) return;
    final text = date.toIso8601String().substring(0, 10);
    if (_date.text != text) {
      _date.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    _date.dispose();
    _dateFocus.dispose();
    super.dispose();
  }

  void _apply() {
    _normalizeDate();
    if (!_confirmed || !_form.currentState!.validate()) return;
    if (_items.any((item) => ReceiptItem.fromJson(item.toJson()) == null)) {
      setState(() => _itemError = '품목 내용을 확인하거나 제외해주세요.');
      return;
    }
    Navigator.of(context).pop(
      ReceiptDraft(
        merchant: _merchant.text.trim(),
        date: _parsedDate,
        amount: double.parse(_amount.text),
        currency: _currency,
        category: _category,
        warnings: [],
        items: _items,
        taxes: _taxes,
        adjustments: _adjustments,
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
                  const Text('사진과 비교해 내용을 확인해주세요.'),
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
                    decoration: const InputDecoration(labelText: '결제금액'),
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
                    decoration: const InputDecoration(labelText: '결제 통화'),
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
                    key: const ValueKey('receipt-payment-date'),
                    controller: _date,
                    focusNode: _dateFocus,
                    keyboardType: TextInputType.datetime,
                    onChanged: (value) {
                      if (RegExp(r'^\d{8}$').hasMatch(value)) _normalizeDate();
                    },
                    onFieldSubmitted: (_) => _normalizeDate(),
                    decoration: const InputDecoration(
                      labelText: '결제일',
                      hintText: '예: 202691 또는 20260901',
                    ),
                    validator: (_) =>
                        _parsedDate == null ? '올바른 결제일을 확인해주세요' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('추천 카테고리'),
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
                  if (_items.isNotEmpty)
                    ReceiptItems(
                      items: _items,
                      currency: _currency ?? '',
                      onChanged: (items) => setState(() => _items = items),
                    ),
                  for (final tax in _taxes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${tax.label} · ${formatNumber(tax.amount)} ${tax.currency}',
                      ),
                      subtitle: Text(tax.inclusionLabel),
                    ),
                  if (_taxes.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _taxes = []),
                      child: const Text('세금 정보 제외'),
                    ),
                  if (_adjustments != null) ...[
                    for (final line in _adjustments!.details)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${line.label} · ${line.isDiscount ? '할인' : '추가금'}',
                        ),
                        subtitle: Text(
                          '${line.isDiscount ? '−' : '+'}${formatNumber(line.amount)} ${line.currency}',
                        ),
                      ),
                    if (_adjustments!.taxFree != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('면세'),
                        trailing: Text(_adjustments!.taxFree! ? '적용' : '미적용'),
                      ),
                    for (final entry in {
                      '면세액': _adjustments!.exemptedTax,
                      '면세 대상 금액': _adjustments!.taxFreeBase,
                      if (!_adjustments!.details.any((line) => line.isDiscount))
                        '할인액': _adjustments!.discount,
                      if (_adjustments!.details
                              .where((line) => line.isDiscount)
                              .length >
                          1)
                        '할인 합계': _adjustments!.discount,
                    }.entries)
                      if (entry.value != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.key),
                          subtitle: Text(
                            '${formatNumber(entry.value!)} ${_adjustments!.currency ?? '통화 확인 필요'}',
                          ),
                        ),
                    TextButton(
                      onPressed: () => setState(() => _adjustments = null),
                      child: const Text('면세·추가금·할인 정보 제외'),
                    ),
                  ],
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _confirmed,
                    title: const Text('상호명·날짜·최종 금액·통화·추가금·할인을 원본과 비교했어요'),
                    onChanged: (value) =>
                        setState(() => _confirmed = value ?? false),
                  ),
                  if (_itemError != null)
                    Text(
                      _itemError!,
                      style: const TextStyle(color: AppColors.danger),
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
