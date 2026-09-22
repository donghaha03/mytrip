import 'package:flutter/material.dart';

import '../models/country.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'won_input_formatter.dart';

/// 빠른 환산 계산기. 물건 값 보고 "이거 원화로 얼마지?" 할 때 쓴다.
///
/// 기록은 남기지 않는다 — 지출 기록은 장부 몫이다.
/// 환율은 country.krwPerUnit 을 그대로 쓴다 (환율 API 가 붙으면 같이 바뀐다).
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
    // 방향을 바꿀 때 지금 결과를 새 입력으로 넘겨서 흐름이 안 끊기게 한다
    final value = parseAmount(_input.text);
    setState(() => _fromForeign = !_fromForeign);
    if (value == 0) {
      _input.clear();
      return;
    }
    final next = _fromForeign
        ? krwToForeign(_c, value) // 방금까지 원화 입력이었다
        : _c.toKrw(value);
    _input.text = _fromForeign
        ? formatForeignPlain(_c, next)
        : formatNumber(next);
  }

  void _fill(num amount) {
    _input.text = formatNumber(amount);
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final value = parseAmount(_input.text);
    final result = _fromForeign
        ? formatWon(_c.toKrw(value))
        : formatForeignAmount(_c, krwToForeign(_c, value));
    final quick = [10, 50, 100].map((m) => _c.unitAmount * m).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 16),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fromForeign ? '${_c.currency} → KRW' : 'KRW → ${_c.currency}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: '방향 바꾸기',
                child: InkResponse(
                  onTap: _swap,
                  radius: 20,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.swap_vert_rounded,
                        size: 20, color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextField(
              controller: _input,
              keyboardType: TextInputType.numberWithOptions(
                  decimal: _fromForeign && _hasCents(_c)),
              inputFormatters: [
                AmountInputFormatter(
                    decimals: _fromForeign && _hasCents(_c) ? 2 : 0),
              ],
              cursorColor: AppColors.primary,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                // prefixText 는 포커스가 있거나 값이 있을 때만 보여서, 빈 칸에
                // "0" 만 덩그러니 남는다. 통화 기호는 항상 보이게 prefixIcon 으로.
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 8),
                  child: Text(
                    _fromForeign ? _c.symbol : kWonSymbol,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                filled: true,
                fillColor: AppColors.bg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  '=',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: value == 0
                          ? AppColors.textTertiary
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_fromForeign) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (final q in quick) ...[
                  _QuickChip(
                    label: _c.formatForeign(q),
                    onTap: () => _fill(q),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '${_c.rateLabel} 기준',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 환산 도우미 (테스트에서도 쓰려고 공개)
// ---------------------------------------------------------------------------

/// 원화 -> 현지 통화
double krwToForeign(Country c, double krw) =>
    krw * c.unitAmount / c.krwPerUnit;

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
