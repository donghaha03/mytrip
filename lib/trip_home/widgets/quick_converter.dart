import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../models/country.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'won_input_formatter.dart';

/// 빠른 환산 계산기. 물건 값 보고 "이거 원화로 얼마지?" 할 때 쓴다.
///
///   빠른 환산  JPY → KRW                ⇅
///   [ ¥  1,500        ]  =   14,250원
///
/// 기록은 남기지 않는다. 최신 API 환율을 사용하며, 환율이 없으면 계산하지 않는다.
class QuickConverter extends StatefulWidget {
  const QuickConverter({super.key, required this.country});

  final Country country;

  @override
  State<QuickConverter> createState() => _QuickConverterState();
}

class _QuickConverterState extends State<QuickConverter> {
  final _input = TextEditingController();

  /// true: 현지 통화 -> 원화, false: 원화 -> 현지 통화
  bool _fromForeign = true;

  Country get _c => widget.country;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _swap() {
    if (RateApi.krwPer(_c.currency) <= 0) return;
    // 방향을 바꿀 때 지금 결과를 새 입력으로 넘겨서 흐름이 안 끊기게 한다
    final value = parseAmount(_input.text);
    setState(() => _fromForeign = !_fromForeign);
    if (value == 0) {
      _input.clear();
      return;
    }
    _input.text = _fromForeign
        ? formatForeignPlain(_c, RateApi.fromKrw(value, _c.currency))
        : formatNumber(RateApi.toKrw(value, _c.currency));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: RateApi.changes,
    builder: (context, _) => _buildConverter(),
  );

  Widget _buildConverter() {
    final value = parseAmount(_input.text);
    final available = RateApi.krwPer(_c.currency) > 0;
    final result = !available
        ? '환율 없음'
        : _fromForeign
        ? formatWon(RateApi.toKrw(value, _c.currency))
        : formatForeignAmount(_c, RateApi.fromKrw(value, _c.currency));
    final cents = _fromForeign && _hasCents(_c);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                '빠른 환산',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _fromForeign ? '${_c.currency} → KRW' : 'KRW → ${_c.currency}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: '방향 바꾸기',
                child: InkResponse(
                  onTap: available ? _swap : null,
                  radius: 18,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.swap_vert_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  enabled: available,
                  controller: _input,
                  keyboardType: TextInputType.numberWithOptions(decimal: cents),
                  inputFormatters: [
                    AmountInputFormatter(decimals: cents ? 2 : 0),
                  ],
                  cursorColor: AppColors.primary,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '0',
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    // prefixText 는 포커스가 있거나 값이 있을 때만 보여서, 빈 칸에
                    // "0" 만 덩그러니 남는다. 통화 기호는 항상 보이게 prefixIcon 으로.
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 6),
                      child: Text(
                        _fromForeign ? _c.symbol : kWonSymbol,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '=',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  result,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: value == 0
                        ? AppColors.textTertiary
                        : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '적용 환율: ${currentRateLabel(_c)}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const Text(
            'API 기준 · 원화 결과는 1원 단위 반올림',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 환산 도우미 (테스트에서도 쓰려고 공개)
// ---------------------------------------------------------------------------

/// 상단과 계산기에 같은 API 환율을 표시한다. 계산에는 반올림 전 값을 쓴다.
String currentRateLabel(Country c) {
  if (RateApi.krwPer(c.currency) <= 0) {
    return RateApi.isLoading ? '환율 확인 중' : '환율 없음';
  }
  final won = RateApi.toKrw(c.unitAmount.toDouble(), c.currency);
  return '${c.formatForeign(c.unitAmount)} ≈ $kWonSymbol${won.toStringAsFixed(2)}';
}

/// 1 단위가 100원 이상인 통화(달러·유로·파운드·위안 …)는 센트 단위까지 쓴다.
/// 엔·동·바트처럼 단위가 작은 통화는 정수로 충분하다.
bool _hasCents(Country c) => c.krwPerUnit / c.unitAmount >= 100;

/// 기호 없이: 달러면 "7.41", 엔이면 "1,000"
String formatForeignPlain(Country c, double v) {
  if (!_hasCents(c)) return formatNumber(v);
  final cents = (v * 100).round();
  final whole = cents ~/ 100;
  final frac = (cents % 100).toString().padLeft(2, '0');
  return '${formatNumber(whole)}.$frac';
}

/// 기호 포함: "$7.41", "¥1,000"
String formatForeignAmount(Country c, double v) =>
    '${c.symbol}${formatForeignPlain(c, v)}';
